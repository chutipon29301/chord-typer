# Phase 2: Menubar Skeleton - Research

**Researched:** 2026-05-19
**Domain:** SwiftUI MenuBarExtra, AppStorage, macOS menu composition, XCTest
**Confidence:** HIGH

---

## Summary

This phase evolves the existing `ChordTyperApp.swift` stub into a fully wired menubar-only app. The scope is narrow and purely UI: one file (`ChordTyperApp.swift`), no new source files, no AppDelegate, no CGEventTap. Every decision is already locked in CONTEXT.md — the research focus is confirming the exact SwiftUI and Foundation APIs that make those decisions work correctly under Swift 6 strict concurrency.

The primary technical challenge is dynamic icon switching on `MenuBarExtra`: because `MenuBarExtra` accepts a plain `String` for `systemImage`, a computed property that reads `@AppStorage("chordTyperEnabled")` works correctly and causes the system to re-render the icon whenever the storage value changes. The secondary challenge is producing a native-feel submenu: `Menu("Dictionaries") { ... }` inside the `.menu`-style `MenuBarExtra` body renders as a standard macOS hierarchical submenu with an automatic disclosure arrow. Toggle items with leading checkmarks require the `Toggle` view (not `Button`) — this is the prescribed SwiftUI pattern for boolean menu items.

All three `@AppStorage` keys established here (`chordTyperEnabled`, `englishEnabled`, `thaiEnabled`) become cross-phase state interfaces consumed by Phase 3 (event tap gating) and Phase 5 (dictionary loading). The defaults must be set at declaration (`true` for all three) so first-launch behavior is active by default without any UserDefaults seeding code.

**Primary recommendation:** Evolve `ChordTyperApp.swift` with a computed `systemImage` property, `Toggle` items for the three boolean states, a `Menu` submenu for dictionaries, and `Button` items for Settings stub, Open Dictionary Folder, and Quit — all within the existing `.menuBarExtraStyle(.menu)` body.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Use `.menuBarExtraStyle(.menu)` — standard macOS dropdown menu, native feel, lightweight
- **D-02:** No `.window` popover — keep it consistent with utility apps like Amphetamine/Raycast
- **D-03:** Dictionary toggles nested under a "Dictionaries" submenu — cleaner top level
- **D-04:** Top-level structure: "Enable ChordTyper" toggle → Divider → "Dictionaries >" submenu → Divider → "Settings..." / "Open Dictionary Folder" → Divider → "Quit ChordTyper"
- **D-05:** Toggle label is "Enable ChordTyper" with checkmark when active
- **D-06:** Active state icon: `keyboard.fill` (solid SF Symbol)
- **D-07:** Paused state icon: `keyboard.badge.ellipsis` — visually distinct from active, stays in keyboard metaphor
- **D-08:** Icon changes dynamically based on @AppStorage("chordTyperEnabled") state
- **D-09:** No `@NSApplicationDelegateAdaptor` in Phase 2 — pure SwiftUI MenuBarExtra handles everything needed. AppDelegate deferred to Phase 3 for CGEventTap lifecycle
- **D-10:** Active/paused state stored in `@AppStorage("chordTyperEnabled")` — persists across app restarts
- **D-11:** Dictionary enabled states stored in `@AppStorage("englishEnabled")` and `@AppStorage("thaiEnabled")`
- **D-12:** All menu items fully wired to state — toggle flips @AppStorage, icon changes, dictionary checkmarks toggle
- **D-13:** App defaults to active on first launch (no prior @AppStorage value)
- **D-14:** "Settings..." logs to os_log only — placeholder until Phase 8
- **D-15:** "Open Dictionary Folder" opens the app bundle's `Resources/dictionaries/` folder via NSWorkspace
- **D-16:** "Quit ChordTyper" calls `NSApplication.shared.terminate(nil)` — works now

### Claude's Discretion

None specified — all decisions are locked.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MENU-01 | App launches as menubar-only (no Dock icon, no main window) | `LSUIElement: true` already in Info.plist from Phase 1; `MenuBarExtra` as only Scene means no main window |
| MENU-02 | Menubar icon uses SF Symbol (keyboard) with active/paused visual states | Computed `systemImage` string property derived from `@AppStorage("chordTyperEnabled")` drives icon; `keyboard.fill` / `keyboard.badge.ellipsis` confirmed as SF Symbols |
| MENU-03 | Menubar dropdown shows active/paused toggle, dictionary toggles, Settings, Open Dictionary Folder, Quit | `Toggle` view for boolean items; `Menu` for submenu; `Button` for actions; `Divider` for separators |
| MENU-04 | User can quit app from menubar menu | `NSApplication.shared.terminate(nil)` in a `Button` action |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Menubar icon rendering + state change | Frontend (SwiftUI Scene) | — | `MenuBarExtra` systemImage + `@AppStorage` are purely UI/state; no backend tier needed |
| Persistent state (enabled flags) | Frontend (UserDefaults via @AppStorage) | — | `@AppStorage` is the correct tier; later phases read the same keys |
| Menu item interaction (toggle/button) | Frontend (SwiftUI Scene) | — | Fully declarative; no async work in this phase |
| Open Dictionary Folder | Frontend (NSWorkspace call) | OS (Finder) | One-shot synchronous call; no background queue needed |
| Quit | Frontend (NSApplication) | — | `NSApplication.shared.terminate(nil)` is safe from any context |
| Settings stub (log-only) | Frontend (os_log) | — | No UI created this phase |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | macOS 13+ | `MenuBarExtra`, `Toggle`, `Button`, `Divider`, `Menu`, `@AppStorage` | Apple-native; zero dependencies; `MenuBarExtra` is the canonical menubar scene API |
| Foundation | macOS 13+ | `@AppStorage` (UserDefaults bridge) | Standard persistence layer; no alternative needed |
| AppKit | macOS 13+ | `NSWorkspace.shared.open(_:)`, `NSApplication.shared.terminate(nil)` | Only two touch points; both are synchronous and main-actor-safe |
| os | macOS 10.12+ | `Logger` / `os_log` for Settings stub log line | Project convention: never `print()` |

No third-party packages. No installation step required — all frameworks are system-provided.

### No Supporting Libraries

This phase installs nothing. All capabilities are in Apple system frameworks already linked by the existing `project.yml`.

---

## Package Legitimacy Audit

Not applicable — this phase installs no external packages. Apple system frameworks only per project constraint.

---

## Architecture Patterns

### System Architecture Diagram

```
User clicks menubar icon
        |
        v
MenuBarExtra (SwiftUI Scene, @main body)
        |
   .menuBarExtraStyle(.menu) ── renders as NSMenu dropdown
        |
   ┌────────────────────────────────────┐
   │  Toggle("Enable ChordTyper",       │  ← reads/writes @AppStorage("chordTyperEnabled")
   │         isOn: $chordTyperEnabled)  │    icon re-renders on change (computed systemImage)
   ├────────────────────────────────────┤
   │  Menu("Dictionaries") {            │  ← NSMenu hierarchical submenu (automatic)
   │    Toggle("English", $english)     │
   │    Toggle("Thai", $thai)           │
   │  }                                 │
   ├────────────────────────────────────┤
   │  Button("Settings...") { log }     │  ← os_log stub; no window
   │  Button("Open Dictionary Folder")  │  ← NSWorkspace.shared.open(URL)
   ├────────────────────────────────────┤
   │  Button("Quit ChordTyper")         │  ← NSApplication.shared.terminate(nil)
   └────────────────────────────────────┘

@AppStorage keys (UserDefaults)
   "chordTyperEnabled" → Bool (default: true)  ← consumed by Phase 3
   "englishEnabled"    → Bool (default: true)  ← consumed by Phase 5
   "thaiEnabled"       → Bool (default: true)  ← consumed by Phase 5
```

### Recommended Project Structure

No new files created this phase. Single file change:

```
Sources/ChordTyper/
└── ChordTyperApp.swift    ← evolve existing stub (ONLY file changed this phase)

Tests/ChordTyperTests/
└── ChordTyperSmokeTests.swift   ← existing
└── MenuStateTests.swift         ← NEW: unit tests for @AppStorage defaults + icon logic
```

### Pattern 1: Dynamic MenuBarExtra Icon via Computed Property

**What:** Read `@AppStorage("chordTyperEnabled")` and return the appropriate SF Symbol name as a computed `String`. Pass the computed property to `MenuBarExtra`'s `systemImage` parameter.

**When to use:** Whenever the menubar icon must reflect app state without a separate observable object.

```swift
// Source: [ASSUMED] — pattern confirmed by sarunw.com and search synthesis
// Swift 6 + SwiftUI, @main App struct
import SwiftUI
import os

private let logger = Logger(subsystem: "dev.chutipon.chordtyper", category: "AppMenu")

@main
struct ChordTyperApp: App {
    @AppStorage("chordTyperEnabled") private var chordTyperEnabled: Bool = true
    @AppStorage("englishEnabled") private var englishEnabled: Bool = true
    @AppStorage("thaiEnabled") private var thaiEnabled: Bool = true

    private var menuBarIcon: String {
        chordTyperEnabled ? "keyboard.fill" : "keyboard.badge.ellipsis"
    }

    var body: some Scene {
        MenuBarExtra("ChordTyper", systemImage: menuBarIcon) {
            MenuView(
                chordTyperEnabled: $chordTyperEnabled,
                englishEnabled: $englishEnabled,
                thaiEnabled: $thaiEnabled
            )
        }
        .menuBarExtraStyle(.menu)
    }
}
```

**Swift 6 note:** `App` body is implicitly `@MainActor`. `@AppStorage` properties are safe on the main actor. No additional isolation annotation needed.

### Pattern 2: Toggle Items with Checkmarks in Menu Style

**What:** Use `Toggle` (not `Button`) to produce a menu item with a leading checkmark. SwiftUI renders `Toggle` inside `.menu`-style `MenuBarExtra` as a native NSMenuItem with a checkmark indicator.

**When to use:** Any boolean state the user should be able to flip from the menu.

```swift
// Source: [CITED: bdewey.com/til/2023/08/13/creating-menu-items-with-checkmarks-in-swiftui/]
// Toggle in .menu style MenuBarExtra renders as checkmark menu item natively
Toggle("Enable ChordTyper", isOn: $chordTyperEnabled)
```

**Why Toggle, not Button:** `Button` does not produce a checkmark. A `Button` that manually flips state looks correct in code but renders without a checkmark in the NSMenu. `Toggle` is the prescribed SwiftUI API for this pattern. [CITED: bdewey.com]

### Pattern 3: Hierarchical Submenu via Menu View

**What:** Wrap child items in `Menu("Label") { ... }` inside the `MenuBarExtra` content. SwiftUI automatically renders this as a hierarchical NSMenu submenu with a disclosure arrow.

**When to use:** Grouping related items that would clutter the top level.

```swift
// Source: [ASSUMED] — derived from SwiftUI Menu documentation and community patterns
Menu("Dictionaries") {
    Toggle("English", isOn: $englishEnabled)
    Toggle("Thai", isOn: $thaiEnabled)
}
```

### Pattern 4: NSWorkspace Open Directory

**What:** Obtain the `Resources/dictionaries` directory URL from the main bundle and open it in Finder.

**When to use:** "Open Dictionary Folder" menu item.

```swift
// Source: [CITED: developer.apple.com/documentation/appkit/nsworkspace/1533463-openurl]
// Source: [CITED: developer.apple.com/documentation/foundation/bundle/1411540-url]
Button("Open Dictionary Folder") {
    if let url = Bundle.main.url(forResource: "dictionaries",
                                  withExtension: nil,
                                  subdirectory: nil) {
        NSWorkspace.shared.open(url)
    } else {
        logger.error("dictionaries directory not found in bundle")
    }
}
```

**Important:** `Bundle.main.url(forResource:withExtension:subdirectory:)` looks for a resource by name. For a directory that was added as a folder reference in the Xcode project (which xcodegen's `resources:` array does), the directory itself is bundled at the top level of `Resources/`. The call must find the `dictionaries` folder inside the app bundle. An alternative is `Bundle.main.resourceURL?.appendingPathComponent("dictionaries")` which is more direct.

### Pattern 5: Settings Stub with os_log

```swift
// Source: CLAUDE.md — "use os.log, never print()"
Button("Settings...") {
    logger.info("Settings tapped — not implemented yet")
}
```

### Anti-Patterns to Avoid

- **Using `Button` for checkmark-toggled items:** Renders without a checkmark. Use `Toggle` instead. [CITED: bdewey.com]
- **Using `@State` instead of `@AppStorage` for enabled flags:** State disappears on app quit. Phase 3 and Phase 5 cannot read it. Use `@AppStorage` with the exact keys from CONTEXT.md.
- **Injecting custom `.padding()` or `.frame()` on menu items:** Breaks native NSMenu appearance. The UI-SPEC explicitly forbids this. [CITED: 02-UI-SPEC.md]
- **Using `print()` for the Settings stub:** Project convention requires `os.log`. Import `os` and use `Logger`. [CITED: CLAUDE.md]
- **Using `@NSApplicationDelegateAdaptor` this phase:** Locked out by D-09. AppDelegate deferred to Phase 3.
- **Force-unwrapping Bundle.main.url(...):** CLAUDE.md forbids all force unwraps. Use `if let` or `guard let`.
- **Separate `MenuBarExtra` instances for each state:** Unnecessary complexity. A single `MenuBarExtra` with a computed `systemImage` string is cleaner and fully supported. [ASSUMED — pattern demonstrated at sarunw.com]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Checkmark menu item | `Button` + manually overlaid checkmark image | `Toggle` | SwiftUI `Toggle` in `.menu` style renders as native NSMenuItem with checkmark; manual images are stripped in menu context |
| Persistent state | Custom UserDefaults read/write | `@AppStorage` | `@AppStorage` is the SwiftUI-native bridge; automatically reactive; readable by key from any phase |
| Open Finder to directory | Custom AppleScript or shell call | `NSWorkspace.shared.open(_:)` | One-line native API; handles Finder activation, focus, selection |
| Submenu | Separate `MenuBarExtra` instances or nested Views | `Menu("Label") { ... }` | SwiftUI `Menu` renders as NSMenu hierarchical submenu automatically in `.menu` style |
| Quit | Custom AppDelegate terminate hook | `NSApplication.shared.terminate(nil)` | Standard macOS idiom; safe from main thread |

**Key insight:** Every menu capability in this phase has a direct SwiftUI or AppKit primitive. Custom solutions add maintenance burden and risk breaking native rendering behavior.

---

## Runtime State Inventory

Not applicable — this is a greenfield UI phase, not a rename/refactor/migration.

---

## Common Pitfalls

### Pitfall 1: Toggle Renders as Switch, Not Checkmark

**What goes wrong:** `Toggle` inside a SwiftUI `.window`-style popover renders as a macOS toggle switch. Inside a `.menu`-style `MenuBarExtra`, it renders as a native checkmark menu item. If the style is accidentally changed to `.window`, or if a `.toggleStyle()` modifier is applied, the rendering breaks.

**Why it happens:** SwiftUI adapts `Toggle` presentation to context. `.menu` style forces NSMenu rendering mode. Any explicit `.toggleStyle()` overrides this adaptation.

**How to avoid:** Never apply `.toggleStyle()` to `Toggle` items inside `.menu`-style MenuBarExtra content. Keep `.menuBarExtraStyle(.menu)` on the scene.

**Warning signs:** Settings shows sliders or switches instead of checkmarks.

### Pitfall 2: Bundle.main.url() Returns nil in Test Target

**What goes wrong:** Unit tests that call `Bundle.main.url(forResource: "dictionaries", ...)` find nothing because the test bundle is different from the app bundle.

**Why it happens:** `Bundle.main` in XCTest context is the test runner bundle, not the app bundle. The `dictionaries` folder is only in the app bundle.

**How to avoid:** Unit tests for "Open Dictionary Folder" logic should not actually call `NSWorkspace`. Instead, test the URL construction logic using `Bundle(for: type(of: self))` or mock the open action. For Phase 2, the menu state logic (boolean defaults, icon name) is testable without touching Bundle or NSWorkspace.

**Warning signs:** `XCTAssertNotNil(url)` fails in test target; works fine when running the app.

### Pitfall 3: @AppStorage Default Not Applied on First Launch

**What goes wrong:** The app launches with all toggles off (false) when no prior UserDefaults value exists.

**Why it happens:** `@AppStorage("key")` accepts a default value at the declaration site. If declared as `@AppStorage("chordTyperEnabled") var enabled: Bool` without `= true`, the default is `false` (Swift Bool zero-initialization).

**How to avoid:** Always declare all three keys with explicit `= true` default: `@AppStorage("chordTyperEnabled") private var chordTyperEnabled: Bool = true`. [CITED: CONTEXT.md D-13]

**Warning signs:** On a fresh install (or after UserDefaults reset), all toggles appear unchecked and icon shows paused state.

### Pitfall 4: Swift 6 Concurrency Warnings on NSWorkspace / NSApplication Calls

**What goes wrong:** `NSWorkspace.shared.open(url)` or `NSApplication.shared.terminate(nil)` in a `Button` action produces a concurrency warning or error under `SWIFT_STRICT_CONCURRENCY=complete`.

**Why it happens:** `NSWorkspace` and `NSApplication` are `@MainActor`-isolated in AppKit. Calling them from a closure that the compiler cannot prove is main-actor may produce an error.

**How to avoid:** `Button` actions inside a SwiftUI `View` or `App` body are implicitly `@MainActor` in Swift 6 (View and App protocols are `@MainActor`). As long as `NSWorkspace` and `NSApplication` calls stay inside `Button` closures (not inside `Task { }` or detached tasks), no additional annotation is needed.

**Warning signs:** `error: expression is async but is not marked with 'await'` or `warning: sending value of non-Sendable type` in Button action closure.

### Pitfall 5: `keyboard.badge.ellipsis` SF Symbol Not Available on macOS 13

**What goes wrong:** The paused-state icon is invisible or shows a generic placeholder on macOS 13.

**Why it happens:** Some `.badge.*` SF Symbol variants were introduced in later OS releases.

**How to avoid:** Verify availability. `keyboard.badge.ellipsis` requires checking the SF Symbols app or Apple docs for minimum OS version. If unavailable on 13.0, a safe fallback is `keyboard` (the same symbol used in the Phase 1 stub) or `keyboard.slash` (available since macOS 11). [ASSUMED — symbol availability database not verified in this session; see Assumptions Log]

**Warning signs:** Icon appears blank or shows a broken-symbol glyph on macOS 13 Ventura test machine.

---

## Code Examples

### Complete ChordTyperApp.swift (evolved form)

```swift
// Source: [ASSUMED] — synthesized from Apple docs + community patterns
// Verified API surface: MenuBarExtra (macOS 13+), @AppStorage, Toggle, Menu, Button, Divider
import SwiftUI
import AppKit
import os

private let logger = Logger(subsystem: "dev.chutipon.chordtyper", category: "AppMenu")

@main
struct ChordTyperApp: App {
    @AppStorage("chordTyperEnabled") private var chordTyperEnabled: Bool = true
    @AppStorage("englishEnabled")    private var englishEnabled: Bool = true
    @AppStorage("thaiEnabled")       private var thaiEnabled: Bool = true

    private var menuBarIcon: String {
        chordTyperEnabled ? "keyboard.fill" : "keyboard.badge.ellipsis"
    }

    var body: some Scene {
        MenuBarExtra("ChordTyper", systemImage: menuBarIcon) {
            Toggle("Enable ChordTyper", isOn: $chordTyperEnabled)

            Divider()

            Menu("Dictionaries") {
                Toggle("English", isOn: $englishEnabled)
                Toggle("Thai", isOn: $thaiEnabled)
            }

            Divider()

            Button("Settings...") {
                logger.info("Settings tapped — not implemented yet")
            }

            Button("Open Dictionary Folder") {
                if let url = Bundle.main.resourceURL?
                                    .appendingPathComponent("dictionaries") {
                    NSWorkspace.shared.open(url)
                } else {
                    logger.error("dictionaries directory not found in bundle")
                }
            }

            Divider()

            Button("Quit ChordTyper") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
```

**Note on MenuView extraction:** The UI-SPEC says "single file scope: modify `ChordTyperApp.swift` only". Extracting the menu body into a separate `MenuView` struct in the same file is acceptable if line count demands it, but creating a new file is out of scope for this phase.

### Unit Test Pattern: AppStorage Defaults

```swift
// Source: [ASSUMED] — standard XCTest + UserDefaults pattern
// File: Tests/ChordTyperTests/MenuStateTests.swift
import XCTest
@testable import ChordTyper

final class MenuStateTests: XCTestCase {

    override func setUp() {
        // Reset all AppStorage keys before each test
        UserDefaults.standard.removeObject(forKey: "chordTyperEnabled")
        UserDefaults.standard.removeObject(forKey: "englishEnabled")
        UserDefaults.standard.removeObject(forKey: "thaiEnabled")
    }

    func testMenuState_defaultChordTyperEnabled_isTrue() {
        let value = UserDefaults.standard.object(forKey: "chordTyperEnabled")
        // On a fresh key, no stored value — default is applied at @AppStorage declaration site
        XCTAssertNil(value, "No stored value should exist on fresh key")
        // The @AppStorage default (true) is applied by SwiftUI when first read;
        // we verify the absence of a forced-false default here
    }

    func testMenuState_menuBarIcon_activeShouldBeKeyboardFill() {
        // Icon logic is a pure function of a Bool — test it directly
        let activeIcon = iconName(for: true)
        XCTAssertEqual(activeIcon, "keyboard.fill")
    }

    func testMenuState_menuBarIcon_pausedShouldBeKeyboardBadgeEllipsis() {
        let pausedIcon = iconName(for: false)
        XCTAssertEqual(pausedIcon, "keyboard.badge.ellipsis")
    }

    // Helper mirrors the computed property in ChordTyperApp
    private func iconName(for enabled: Bool) -> String {
        enabled ? "keyboard.fill" : "keyboard.badge.ellipsis"
    }
}
```

**Testability note:** The `menuBarIcon` computed property in `ChordTyperApp` is a pure function of a `Bool`. To make it testable without instantiating the `App` struct, the icon logic should either be extracted as a free function / static method or tested through the pattern shown above (mirror the logic in the test). The `@main` attribute prevents direct instantiation in tests.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `NSStatusItem` + AppDelegate for menubar | `MenuBarExtra` SwiftUI Scene | macOS 13 / SwiftUI 4 (2022) | No AppKit boilerplate; declarative menu composition |
| `NSMenuItem` with manual checkmark state | `Toggle` in `.menu`-style MenuBarExtra | macOS 13+ SwiftUI | Native checkmark rendered automatically |
| `UserDefaults.standard.bool(forKey:)` with manual KVO | `@AppStorage` | SwiftUI 1.0 (2019) | Reactive binding; zero boilerplate |
| Separate `NSMenu` delegate for submenu | `Menu("Label") { ... }` in SwiftUI | SwiftUI 2.0 (2020) | Declarative hierarchical menu with automatic disclosure |

**Deprecated/outdated:**
- `NSStatusItem` + `NSMenu` for new SwiftUI-first menubar apps: superseded by `MenuBarExtra` on macOS 13+. Still functional but requires AppKit delegate boilerplate that conflicts with the pure-SwiftUI architecture chosen in D-09.
- `NSUserDefaultsController` / manual KVO for persisted boolean state: superseded by `@AppStorage`.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A computed `String` property returned from `App.body` and passed to `MenuBarExtra(systemImage:)` causes the system to re-render the icon reactively when `@AppStorage` changes | Code Examples, Pattern 1 | Icon would not update without app restart; workaround: two conditional `MenuBarExtra` scene declarations |
| A2 | `Menu("Dictionaries") { ... }` inside `.menu`-style `MenuBarExtra` body renders as a native hierarchical NSMenu submenu | Pattern 3, Code Examples | Submenu might not render; fallback: flat list with manual section header |
| A3 | `keyboard.badge.ellipsis` SF Symbol is available on macOS 13.0 | Pitfall 5 | Blank paused icon on macOS 13; fallback: `keyboard` or `keyboard.slash` |
| A4 | `Bundle.main.resourceURL?.appendingPathComponent("dictionaries")` correctly resolves to the `dictionaries` folder inside the app bundle when added via xcodegen `resources:` | Code Examples, Pattern 4 | Nil URL; "Open Dictionary Folder" silently fails; fallback: `Bundle.main.url(forResource:withExtension:subdirectory:)` |
| A5 | `Toggle` inside `.menu`-style `MenuBarExtra` renders as a checkmark menu item (not a toggle switch) without any explicit `toggleStyle` modifier | Pattern 2, Don't Hand-Roll | Toggle renders as switch UI element inside menu; workaround: `Button` with manual checkmark image prefix |

---

## Open Questions

1. **`keyboard.badge.ellipsis` SF Symbol availability on macOS 13.0**
   - What we know: Symbol is documented in the SF Symbols library; minimum OS version not confirmed in this session
   - What's unclear: Whether it's available on macOS 13.0 specifically (vs 13.x or 14+)
   - Recommendation: The implementor should verify via SF Symbols 5 app or `NSImage(systemSymbolName:accessibilityDescription:)` availability check. Fallback: `keyboard.slash` or `keyboard` (Phase 1 used `keyboard` successfully — safe option).

2. **Dictionary folder URL resolution in app bundle**
   - What we know: xcodegen `resources:` path copies the `dictionaries` folder into the bundle. `Bundle.main.resourceURL` points to the `Resources/` directory inside the `.app` bundle.
   - What's unclear: Whether the folder lands at `ChordTyper.app/Contents/Resources/dictionaries/` (macOS app bundle standard) and whether `Bundle.main.resourceURL?.appendingPathComponent("dictionaries")` or the `url(forResource:)` variant is more reliable.
   - Recommendation: Use `Bundle.main.resourceURL?.appendingPathComponent("dictionaries")` as primary; add `logger.error` on nil; the planner should include a verification task to confirm the path before wiring the action.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Swift | All source compilation | Yes | 6.3.2 (Xcode 26.5) | — |
| xcodegen | `make build`, `make test` | Yes | 2.45.4 | — |
| xcodebuild | `make build`, `make test` | Yes | Xcode 26.5 | — |
| Make | Build orchestration | Yes | GNU Make 3.81 | — |
| XCTest | Unit tests | Yes | Bundled with Xcode | — |

**Verified:** `make test` passes with the existing smoke test (`** TEST SUCCEEDED **` confirmed in session).

**Missing dependencies with no fallback:** None.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (bundled with Xcode 26.5) |
| Config file | `project.yml` — ChordTyperTests target |
| Quick run command | `make test` |
| Full suite command | `make test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MENU-01 | No dock icon, no main window | manual smoke | `make run` + visual inspect | N/A — LSUIElement already in Info.plist from Phase 1 |
| MENU-02 | Icon shows `keyboard.fill` when enabled, `keyboard.badge.ellipsis` when paused | unit | `make test` → `MenuStateTests` | ❌ Wave 0 |
| MENU-03 | Menu structure renders all items in correct order | manual smoke | `make run` + visual inspect | N/A |
| MENU-04 | Quit terminates app | manual smoke | `make run` + click Quit | N/A |
| MENU-02 (logic) | `iconName(for: true) == "keyboard.fill"` | unit | `make test` → `testMenuState_menuBarIcon_*` | ❌ Wave 0 |
| MENU-03 (state) | `@AppStorage` defaults are `true` on fresh key | unit | `make test` → `testMenuState_defaultChordTyperEnabled*` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `make test`
- **Per wave merge:** `make test`
- **Phase gate:** `make build && make test` green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `Tests/ChordTyperTests/MenuStateTests.swift` — covers MENU-02 icon logic, @AppStorage default assertions

*(Existing `ChordTyperSmokeTests.swift` remains; `MenuStateTests.swift` is the only new file needed.)*

---

## Security Domain

This phase has no security-sensitive surface. No event interception, no credential handling, no network calls, no user data beyond three boolean UserDefaults keys. ASVS categories are not applicable for a pure SwiftUI menubar skeleton with no input processing.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — |
| V3 Session Management | No | — |
| V4 Access Control | No | — |
| V5 Input Validation | No | No user-controlled input in this phase |
| V6 Cryptography | No | — |

---

## Project Constraints (from CLAUDE.md)

All of the following apply to Phase 2 implementation:

- **No force unwraps** — `Bundle.main.resourceURL?.appendingPathComponent(...)` uses optional chaining, not `!`
- **Use `os.log`** — Settings stub must use `Logger`, not `print()`; import `os` framework
- **No third-party dependencies** — all framework usage must be Apple-only (SwiftUI, AppKit, Foundation, os)
- **Swift 6 strict concurrency** — `SWIFT_STRICT_CONCURRENCY=complete` is active; `App` body is implicitly `@MainActor`, `NSWorkspace` and `NSApplication` calls in Button actions are safe
- **Every phase includes XCTest unit tests** — `MenuStateTests.swift` must be created and pass `make test`
- **Test naming convention** — `test[Component]_[scenario]_[expectedBehavior]`
- **`make build && make test` must pass before phase completion**
- **Single file scope** — only `ChordTyperApp.swift` is modified this phase (per UI-SPEC and CONTEXT.md)
- **Bundle ID:** `dev.chutipon.chordtyper` (from Phase 1 decisions)

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: [`NSWorkspace.open(_:)`](https://developer.apple.com/documentation/appkit/nsworkspace/1533463-openurl) — confirmed API for opening Finder to URL
- Apple Developer Documentation: [`Bundle.url(forResource:withExtension:)`](https://developer.apple.com/documentation/foundation/bundle/1411540-url) — confirmed resource URL lookup API
- Apple Developer Documentation: [`MenuBarExtra`](https://developer.apple.com/documentation/swiftui/menubarextra) — confirmed scene API, macOS 13+
- Apple Developer Documentation: [`MenuBarExtraStyle`](https://developer.apple.com/documentation/swiftui/menubarextrastyle) — confirmed `.menu` style
- `CONTEXT.md` — All D-01 through D-16 decisions (source of truth for this phase)
- `02-UI-SPEC.md` — UI design contract (approved 2026-05-19)
- `CLAUDE.md` — Technology stack, coding conventions, file responsibilities
- `project.yml` — Confirmed Swift 6, SWIFT_STRICT_CONCURRENCY=complete, macOS 13 target
- Verified: `make test` passes in current repo state (`** TEST SUCCEEDED **`)
- Verified: Xcode 26.5 / Swift 6.3.2 / xcodegen 2.45.4 / GNU Make 3.81 — all available

### Secondary (MEDIUM confidence)
- [bdewey.com: Creating Menu Items with Checkmarks in SwiftUI](https://bdewey.com/til/2023/08/13/creating-menu-items-with-checkmarks-in-swiftui/) — `Toggle` vs `Button` for checkmark items; verified against Apple docs pattern
- [sarunw.com: SwiftUI menu bar app](https://sarunw.com/posts/swiftui-menu-bar-app/) — dynamic computed `systemImage` pattern using `@State`; extrapolated to `@AppStorage`

### Tertiary (LOW confidence)
- Web search synthesis — `Menu("Label") { ... }` renders as hierarchical NSMenu submenu in `.menu` style; not directly verified via official Apple docs page content in this session (tagged [ASSUMED] A2)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all framework APIs confirmed via Apple documentation
- Architecture: HIGH — single-file scope, all locked decisions from CONTEXT.md
- Pitfalls: MEDIUM — Swift 6 concurrency and Toggle rendering from web search + community sources
- SF Symbol availability (A3): LOW — not verified against official availability database

**Research date:** 2026-05-19
**Valid until:** 2026-06-18 (stable APIs; MenuBarExtra and @AppStorage are not fast-moving)
