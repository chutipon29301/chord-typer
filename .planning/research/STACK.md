# Stack Research

**Domain:** macOS menubar utility with low-level keyboard interception
**Researched:** 2026-05-18
**Confidence:** HIGH (all core APIs are Apple-native with official documentation; no third-party dependencies required or desired)

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Swift | 6.1 (Xcode 16.4) | Implementation language | Apple-first language; concurrency model (actors, async/await) maps cleanly onto event tap callbacks and background dispatch queues. Swift 6 strict concurrency catches data races at compile time — critical for a low-latency event tap running on a background thread. |
| SwiftUI | 5 (macOS 13+) | Menubar UI, Settings window | `MenuBarExtra` scene (macOS 13+) is the canonical SwiftUI-native menubar API — no AppKit `NSStatusItem` boilerplate. Settings window done with SwiftUI `Settings` scene. |
| CoreGraphics / Quartz Event Services | macOS 13+ | Keystroke interception | `CGEventTapCreate` at `.cghidEventTap` location intercepts keystrokes before the IME layer. This is the only public API that works regardless of active input method (critical for Thai IME). All other approaches (NSEvent, Carbon, AXObserver) operate at or above IME and miss raw key codes. |
| Foundation | macOS 13+ | JSON decoding, file watching, timers | `JSONDecoder` for dictionaries; `DispatchSource.makeFileSystemObjectSource` for hot-reload; `DispatchQueue` for background event processing. No alternatives needed. |
| AppKit (minimal) | macOS 13+ | NSPasteboard / CGEventPost for text output | `CGEvent(keyboardEventSource:virtualKey:keyDown:)` + `CGEventPost` or `NSPasteboard` + Cmd-V injection to output chord text. AppKit is only touched for these two paths; SwiftUI handles all UI. |

### Development Tools

| Tool | Version | Purpose | Notes |
|------|---------|---------|-------|
| XcodeGen | 2.45.4 | Generate `.xcodeproj` from `project.yml` | Eliminates `.xcodeproj` merge conflicts; makes the project CLI-buildable without Xcode GUI. `brew install xcodegen`. The `project.yml` should set `INFOPLIST_KEY_LSUIElement: YES` (hides dock icon) and `MACOSX_DEPLOYMENT_TARGET: 13.0`. |
| xcodebuild | Xcode 16.4 | Build and archive | `xcodebuild -scheme ChordTyper -configuration Release build` is the inner loop. Used in Makefile for `make build`, `make run`, `make dmg`. |
| Make | System (macOS ships with GNU Make 3.81) | Build orchestration | Makefile wraps xcodegen + xcodebuild + codesign + hdiutil into `make build`, `make run`, `make dmg`, `make clean`. No external CI system needed for personal use. |
| codesign | System (Xcode CLI tools) | Ad-hoc signing | `codesign --force --deep -s -` for ad-hoc signing. Ad-hoc signed binaries only run on the machine that built them — acceptable for personal use, avoids the Apple Developer account requirement. |
| hdiutil | System (macOS) | DMG packaging | `hdiutil create -volname ChordTyper -srcfolder ChordTyper.app -ov -format UDZO ChordTyper.dmg`. No third-party tools (create-dmg) required for this scope. |

---

## API Details by Feature

### CGEventTap — Keystroke Interception

```swift
// Tap at HID level (before IME) with active filter (can suppress events)
let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
let tap = CGEvent.tapCreate(
    tap: .cghidEventTap,          // Driver level — before IME
    place: .headInsertEventTap,   // First in chain
    options: .defaultTap,         // Active (can return nil to suppress)
    eventsOfInterest: CGEventMask(eventMask),
    callback: eventCallback,
    userInfo: nil
)
// MUST handle kCGEventTapDisabledByTimeout in callback — macOS silently disables taps
// that block events too long. Re-enable with CGEvent.tapEnable(tap:enable:true).
```

**Requires:** Accessibility permission (`AXIsProcessTrusted()`). Prompt via `AXIsProcessTrustedWithOptions`.

**Secure input detection:** CGEventTap stops receiving events when secure keyboard entry is active (password fields, Terminal secure entry). Detect silence and disable chord processing; re-enable when events resume. Use `IOHIDCheckAccess` or monitor tap disable events to infer secure state.

### Text Output — CGEventPost

```swift
// Output a Unicode string as synthetic key events
// Preferred: use CGEvent with unicodeString to avoid virtual key mapping
let source = CGEventSource(stateID: .hidSystemState)
let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
event?.keyboardSetUnicodeString(stringLength: str.utf16.count, unicodeString: Array(str.utf16))
event?.post(tap: .cghidEventTap)
```

Alternative: write to `NSPasteboard.general` then synthesize Cmd-V. Use this only if direct Unicode posting proves unreliable with certain apps (some terminal emulators). Direct `CGEvent` Unicode posting is simpler and avoids clipboard pollution.

### Hot-Reload — DispatchSource

```swift
let fd = open(jsonPath, O_EVTONLY)
let source = DispatchSource.makeFileSystemObjectSource(
    fileDescriptor: fd,
    eventMask: [.write, .rename, .delete],
    queue: .main
)
source.setEventHandler { /* reload JSON */ }
source.resume()
```

`.rename` and `.delete` must be handled because many editors (vim, most IDEs) write atomically by renaming a temp file over the original. On rename/delete, cancel the old source, re-open the fd, and create a new source.

### MenuBarExtra — SwiftUI

```swift
@main
struct ChordTyperApp: App {
    var body: some Scene {
        MenuBarExtra("ChordTyper", systemImage: "keyboard") {
            MenuView()
        }
        .menuBarExtraStyle(.menu)   // Use .menu for simple dropdown; .window for popover panel

        Settings {
            SettingsView()
        }
    }
}
```

`LSUIElement = YES` in Info.plist hides the Dock icon. Set in `project.yml` under `info` or `plist`.

---

## project.yml Skeleton

```yaml
name: ChordTyper
options:
  bundleIdPrefix: com.localdev
  deploymentTarget:
    macOS: "13.0"
  xcodeVersion: "16.4"

settings:
  SWIFT_VERSION: "6.1"
  MACOSX_DEPLOYMENT_TARGET: "13.0"
  ENABLE_HARDENED_RUNTIME: NO  # ad-hoc only; hardened runtime requires Developer ID

targets:
  ChordTyper:
    type: application
    platform: macOS
    sources: Sources/
    info:
      path: Info.plist
      properties:
        LSUIElement: true
        NSAccessibilityUsageDescription: "ChordTyper needs Accessibility access to intercept and suppress keystrokes for chord detection."
    settings:
      CODE_SIGN_IDENTITY: "-"    # ad-hoc
      CODE_SIGN_STYLE: Manual
```

---

## Makefile Pattern

```makefile
SCHEME    = ChordTyper
BUILD_DIR = .build
APP       = $(BUILD_DIR)/$(SCHEME).app

.PHONY: generate build run clean dmg

generate:
	xcodegen generate

build: generate
	xcodebuild -scheme $(SCHEME) -configuration Release \
	  -derivedDataPath $(BUILD_DIR) build

run: build
	open $(APP)

dmg: build
	codesign --force --deep -s - $(APP)
	hdiutil create -volname $(SCHEME) -srcfolder $(APP) \
	  -ov -format UDZO $(BUILD_DIR)/$(SCHEME).dmg

clean:
	rm -rf $(BUILD_DIR) *.xcodeproj
```

---

## Alternatives Considered

| Feature | Recommended | Alternative | Why Not |
|---------|-------------|-------------|---------|
| Keystroke interception | CGEventTap (`.cghidEventTap`) | `NSEvent.addGlobalMonitorForEvents` | NSEvent operates above the IME; Thai key codes are already transformed by the time NSEvent sees them. Cannot suppress events (no return-nil). |
| Keystroke interception | CGEventTap | Carbon `InstallEventHandler` / `RegisterEventHotKey` | Carbon is deprecated in macOS 12+; no Swift overlay; hot-key API doesn't intercept arbitrary keys, only registered combos. |
| Menubar UI | `MenuBarExtra` (SwiftUI) | `NSStatusItem` (AppKit) | `NSStatusItem` requires AppKit delegate boilerplate. `MenuBarExtra` is the modern SwiftUI-native API, available macOS 13+, which matches our deployment target. |
| Menubar UI | `MenuBarExtra` | `NSPopover` + `NSStatusItem` | Extra complexity with no benefit; `MenuBarExtra(.window)` style provides the same popover experience. |
| Text output | `CGEvent` Unicode posting | Clipboard + Cmd-V injection | Clipboard injection pollutes `NSPasteboard` history and has a visible flicker in clipboard managers. Direct `CGEvent` Unicode posting is invisible to clipboard. |
| File watching | `DispatchSource` | `FSEvents` | `FSEvents` is designed for directory trees; `DispatchSource.makeFileSystemObjectSource` is simpler and sufficient for watching 2 specific JSON files. |
| File watching | `DispatchSource` | Third-party (KZFileWatchers, etc.) | Constraint: zero third-party deps. `DispatchSource` is the native primitive — no wrapper needed. |
| Build system | xcodegen + Make | Swift Package Manager | SPM does not support macOS app targets with Info.plist, entitlements, and copy-bundle-resources build phases well. Xcode project is required for CGEventTap entitlements and app bundle structure. |
| Build system | xcodegen + Make | Tuist | Tuist is a valid alternative with better Swift DSL; but xcodegen has broader adoption, simpler YAML config, and no additional toolchain install beyond `brew install xcodegen`. |
| Signing | Ad-hoc (`-s -`) | Developer ID certificate | Requires paid Apple Developer Program ($99/yr). Personal use only — ad-hoc is sufficient and works without an account. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `NSEvent.addGlobalMonitorForEvents` | Operates above IME; can't suppress events; Thai key codes already mangled | `CGEventTap` at `.cghidEventTap` |
| Carbon `RegisterEventHotKey` | Deprecated macOS 12+; only works for pre-registered hotkeys, not arbitrary chord detection | `CGEventTap` |
| `AXObserver` / Accessibility APIs for input | Designed for reading UI state, not intercepting keystrokes; higher latency | `CGEventTap` |
| App Sandbox entitlement | Sandboxed apps cannot use `CGEventPost` to inject synthetic events, and CGEventTap at HID level is restricted. Personal use app has no Sandbox requirement. | Omit sandbox; ad-hoc signed |
| Swift Package Manager as sole build system | Cannot express CGEventTap entitlements, Info.plist properties (`LSUIElement`), or macOS app bundle structure without a wrapper Xcode project | xcodegen + xcodebuild |
| Third-party keyboard libraries (e.g., HotKey, KeyboardShortcuts) | They wrap NSEvent or Carbon — neither works at IME level. Also violates zero-dependency constraint. | Native CGEventTap directly |
| `NSWorkspace.shared.notificationCenter` for IME detection | No reliable notification for "IME changed". CGEventTap silence after `.cghidEventTap` tap disable is the correct signal for secure input. | CGEventTap disable callback |

---

## Version Compatibility

| Component | Version | Compatible With | Notes |
|-----------|---------|-----------------|-------|
| `MenuBarExtra` | SwiftUI 4 | macOS 13.0+ | Introduced macOS 13; confirmed working macOS 13–15. Use `.menuBarExtraStyle(.menu)` for simple dropdown. |
| `CGEventTapCreate` | CoreGraphics | macOS 10.4+, still current macOS 15 | API stable; only the permission model tightened in macOS 12+. Always call `CGPreflightListenEventAccess()` before creating tap. |
| `DispatchSource.makeFileSystemObjectSource` | Foundation | macOS 10.10+ | Stable. Note: atomic-write editors rename files — must watch `.rename` in eventMask and re-open fd. |
| Swift concurrency (`async/await`, actors) | Swift 5.5+ | macOS 12+; macOS 13 for full back-deployment | Use actors to isolate chord state. CGEventTap callback runs on a non-main thread; bridge to actor with `Task { await actor.handle(event) }`. |
| XcodeGen | 2.45.4 | Xcode 16.x | Install via Homebrew: `brew install xcodegen`. |

---

## Sources

- Apple Developer Documentation: [`CGEventTapCreate`](https://developer.apple.com/documentation/coregraphics/1454426-cgeventtapcreate) — tap location options, permission requirements — HIGH confidence
- Apple Developer Documentation: [`CGEvent.tapEnable`](https://developer.apple.com/documentation/coregraphics/cgevent/tapenable(tap:enable:)?language=objc) — re-enable after timeout — HIGH confidence
- Apple Developer Documentation: [`CGEvent.init(keyboardEventSource:virtualKey:keyDown:)`](https://developer.apple.com/documentation/coregraphics/cgevent/1456564-init) — synthetic key event creation — HIGH confidence
- Apple Developer Documentation: [`DispatchSource`](https://developer.apple.com/documentation/dispatch/dispatchsource) — file system event source — HIGH confidence
- Context7 / XcodeGen: `/yonaskolb/xcodegen` — project.yml spec, CLI usage, version 2.45.4 — HIGH confidence
- [nilcoalescing.com: Build a macOS menu bar utility in SwiftUI](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/) — `MenuBarExtra` patterns — MEDIUM confidence (community, verified against Apple docs)
- [swiftrocks.com: DispatchSource file watching](https://swiftrocks.com/dispatchsource-detecting-changes-in-files-and-folders-in-swift) — event mask selection, atomic-write pattern — MEDIUM confidence
- [ghostty-org/ghostty issue #11883](https://github.com/ghostty-org/ghostty/issues/11883) — `kCGEventTapDisabledByTimeout` real-world failure mode — MEDIUM confidence
- [Swift.org: Swift 6.1 Released](https://www.swift.org/blog/swift-6.1-released/) — current Swift version — HIGH confidence
- [xcodereleases.com](https://xcodereleases.com/) — Xcode 16.4 with Swift 6.1 — HIGH confidence

---

*Stack research for: macOS menubar app, CGEventTap chord detection*
*Researched: 2026-05-18*
