# Phase 2: Menubar Skeleton - Pattern Map

**Mapped:** 2026-05-19
**Files analyzed:** 2 (1 modified, 1 created)
**Analogs found:** 2 / 2

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `Sources/ChordTyper/ChordTyperApp.swift` | app-scene (SwiftUI entry point) | event-driven (user interaction → AppStorage) | `Sources/ChordTyper/ChordTyperApp.swift` (current stub) | self — evolve in place |
| `Tests/ChordTyperTests/MenuStateTests.swift` | test | transform (pure Bool → String, UserDefaults read) | `Tests/ChordTyperTests/ChordTyperSmokeTests.swift` | role-match |

---

## Pattern Assignments

### `Sources/ChordTyper/ChordTyperApp.swift` (app-scene, event-driven)

**Analog:** `Sources/ChordTyper/ChordTyperApp.swift` (current stub — evolve, do not replace)

**Current stub** (lines 1–14) — the starting point:
```swift
import SwiftUI

@main
struct ChordTyperApp: App {
    var body: some Scene {
        MenuBarExtra("ChordTyper", systemImage: "keyboard") {
            Text("ChordTyper is running")
                .padding()
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)
    }
}
```

**Imports pattern** — add `AppKit` and `os` to the existing `SwiftUI` import:
```swift
import SwiftUI
import AppKit
import os
```

**Module-level logger** — declare outside the struct (file scope), immediately after imports:
```swift
private let logger = Logger(subsystem: "dev.chutipon.chordtyper", category: "AppMenu")
```
- Subsystem matches bundle ID established in Phase 1 (`dev.chutipon.chordtyper`).
- Category `"AppMenu"` scopes all Phase 2 log lines in Console.app.

**AppStorage declarations pattern** — three stored properties with explicit `= true` defaults, declared before `body`:
```swift
@AppStorage("chordTyperEnabled") private var chordTyperEnabled: Bool = true
@AppStorage("englishEnabled")    private var englishEnabled: Bool = true
@AppStorage("thaiEnabled")       private var thaiEnabled: Bool = true
```
- Keys `chordTyperEnabled`, `englishEnabled`, `thaiEnabled` are the cross-phase state interface (Phase 3 and Phase 5 consume them).
- `= true` default is mandatory — omitting it produces `false` (Swift Bool zero-init), breaking D-13.
- `private` access: no external caller; `@AppStorage` bridges to `UserDefaults.standard` automatically.

**Computed icon property pattern** — pure Bool → String function, declared between stored properties and `body`:
```swift
private var menuBarIcon: String {
    chordTyperEnabled ? "keyboard.fill" : "keyboard.badge.ellipsis"
}
```
- `keyboard.fill` = active state (D-06).
- `keyboard.badge.ellipsis` = paused state (D-07). If unavailable on macOS 13.0, fall back to `keyboard.slash` or `keyboard`.
- Returning a `String` (not an `Image`) to `MenuBarExtra(systemImage:)` is the correct API. SwiftUI re-renders the icon whenever `chordTyperEnabled` changes because `@AppStorage` is reactive.

**MenuBarExtra scene pattern** — full evolved body replacing the stub body:
```swift
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
```

Key points to copy exactly:
- `Toggle` (not `Button`) for all three boolean menu items — `Toggle` renders as a native NSMenuItem with leading checkmark in `.menu` style; `Button` does not produce a checkmark.
- `Menu("Dictionaries") { ... }` — SwiftUI renders this as a hierarchical NSMenu submenu automatically in `.menu` style.
- `.menuBarExtraStyle(.menu)` — must be preserved; removing it or changing to `.window` breaks `Toggle` checkmark rendering.
- `Bundle.main.resourceURL?.appendingPathComponent("dictionaries")` — optional chaining only, no `!` (CLAUDE.md: no force unwraps).
- `NSWorkspace.shared.open(url)` and `NSApplication.shared.terminate(nil)` are called inside `Button` closures, which are implicitly `@MainActor` in a SwiftUI `App` body — safe under `SWIFT_STRICT_CONCURRENCY=complete` without additional annotation.
- `logger.info` / `logger.error` — never `print()` (CLAUDE.md convention).

**Anti-patterns to avoid:**
- Do NOT apply `.toggleStyle()` to any `Toggle` — it overrides the native checkmark rendering.
- Do NOT use `@State` instead of `@AppStorage` — state disappears on app quit; Phase 3/5 cannot read `@State`.
- Do NOT add `.padding()` or `.frame()` to any menu item — breaks native NSMenu appearance (prohibited by UI-SPEC).
- Do NOT declare `@NSApplicationDelegateAdaptor` — deferred to Phase 3 (D-09).

---

### `Tests/ChordTyperTests/MenuStateTests.swift` (test, transform)

**Analog:** `Tests/ChordTyperTests/ChordTyperSmokeTests.swift`

**Test file structure pattern** (lines 1–8 of analog):
```swift
import XCTest

final class ChordTyperSmokeTests: XCTestCase {
    func testSmoke_testPipelineExecutes() {
        XCTAssert(true, "Test pipeline is functional")
    }
}
```
Copy: `import XCTest`, `final class … : XCTestCase`, test naming convention `test[Component]_[scenario]_[expectedBehavior]`.

**setUp / tearDown pattern** — reset UserDefaults keys before each test to prevent inter-test pollution:
```swift
override func setUp() {
    super.setUp()
    UserDefaults.standard.removeObject(forKey: "chordTyperEnabled")
    UserDefaults.standard.removeObject(forKey: "englishEnabled")
    UserDefaults.standard.removeObject(forKey: "thaiEnabled")
}
```
- Required because `@AppStorage` reads `UserDefaults.standard`; a test that writes a key contaminates later tests.

**Icon name logic test pattern** — mirror `menuBarIcon` as a private helper (cannot instantiate `@main` struct directly in tests):
```swift
// Mirror of ChordTyperApp.menuBarIcon — pure function, testable without App instantiation
private func iconName(for enabled: Bool) -> String {
    enabled ? "keyboard.fill" : "keyboard.badge.ellipsis"
}

func testMenuState_menuBarIcon_activeShouldBeKeyboardFill() {
    XCTAssertEqual(iconName(for: true), "keyboard.fill")
}

func testMenuState_menuBarIcon_pausedShouldBeKeyboardBadgeEllipsis() {
    XCTAssertEqual(iconName(for: false), "keyboard.badge.ellipsis")
}
```

**AppStorage defaults test pattern** — verify no forced-false value is pre-seeded:
```swift
func testMenuState_defaultChordTyperEnabled_noStoredValueOnFreshKey() {
    // @AppStorage default (true) is applied by SwiftUI at declaration site.
    // A missing key means the declaration-site default governs — correct behavior.
    XCTAssertNil(UserDefaults.standard.object(forKey: "chordTyperEnabled"),
                 "chordTyperEnabled must have no stored value on fresh key so @AppStorage default applies")
}

func testMenuState_defaultEnglishEnabled_noStoredValueOnFreshKey() {
    XCTAssertNil(UserDefaults.standard.object(forKey: "englishEnabled"))
}

func testMenuState_defaultThaiEnabled_noStoredValueOnFreshKey() {
    XCTAssertNil(UserDefaults.standard.object(forKey: "thaiEnabled"))
}
```

**Note:** `Bundle.main.resourceURL` behavior differs between the app bundle and the XCTest runner bundle. Do NOT test `NSWorkspace.open` or `Bundle.main.url` in unit tests — those are manual smoke tests (`make run` + visual inspect). Unit tests cover only pure-logic paths (icon name, UserDefaults key presence).

---

## Shared Patterns

### Logging
**Source:** `Sources/ChordTyper/ChordTyperApp.swift` (evolved form) + CLAUDE.md convention
**Apply to:** All new source files in this phase and all future phases

```swift
import os

private let logger = Logger(subsystem: "dev.chutipon.chordtyper", category: "<CategoryName>")
```
- Declare at file scope (outside any type), marked `private`.
- Subsystem is always `"dev.chutipon.chordtyper"` (bundle ID from Phase 1).
- Category is the file/component name: `"AppMenu"` for this phase.
- Use `logger.info(...)`, `logger.error(...)` — never `print()`.

### No Force Unwrap
**Source:** CLAUDE.md
**Apply to:** All files

```swift
// Correct — optional chaining
if let url = Bundle.main.resourceURL?.appendingPathComponent("dictionaries") {
    NSWorkspace.shared.open(url)
} else {
    logger.error("dictionaries directory not found in bundle")
}

// Forbidden
let url = Bundle.main.resourceURL!.appendingPathComponent("dictionaries")
```

### Swift 6 Concurrency — AppKit Calls in Button Actions
**Source:** RESEARCH.md Pitfall 4
**Apply to:** Any file that calls `NSWorkspace` or `NSApplication` from SwiftUI views/scenes

`Button` action closures inside SwiftUI `View` or `App` body are implicitly `@MainActor`. Calling `NSWorkspace.shared.open(_:)` and `NSApplication.shared.terminate(nil)` directly inside `Button { }` closures is safe under `SWIFT_STRICT_CONCURRENCY=complete` — no `Task { }` wrapper, no `await`, no additional actor annotation needed.

### AppStorage Key Constants (cross-phase interface)
**Source:** CONTEXT.md D-10, D-11
**Apply to:** Phase 3 (event tap gating), Phase 5 (dictionary loading), and any future phase that reads enabled state

| Key | Type | Default | Consumer Phases |
|-----|------|---------|-----------------|
| `"chordTyperEnabled"` | Bool | true | Phase 3 |
| `"englishEnabled"` | Bool | true | Phase 5 |
| `"thaiEnabled"` | Bool | true | Phase 5 |

Future phases read these via `UserDefaults.standard.bool(forKey:)` or their own `@AppStorage` declaration with matching key strings.

---

## No Analog Found

All files in this phase have analogs. No entries.

---

## Metadata

**Analog search scope:** `Sources/ChordTyper/`, `Tests/ChordTyperTests/`
**Files scanned:** 2 (entire codebase at time of mapping)
**Pattern extraction date:** 2026-05-19
**Note:** Codebase is at Phase 1 stub state — `ChordTyperApp.swift` and `ChordTyperSmokeTests.swift` are the only source files. Pattern extraction draws from the existing stubs plus the locked decisions in CONTEXT.md and RESEARCH.md, which together constitute the full specification for this phase.
