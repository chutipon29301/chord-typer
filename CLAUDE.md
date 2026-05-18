<!-- GSD:project-start source:PROJECT.md -->
## Project

**ChordTyper**

A macOS menubar app that enables chord-based typing on a standard Mac keyboard. Press 3+ keys simultaneously; if the combination matches a dictionary entry, the app suppresses individual keystrokes and outputs the full word. Designed for faster everyday prose — chatting with AI, writing prompts — not developer snippets.

**Core Value:** Chord-based typing must reliably detect simultaneous keypresses and output the correct word, replacing the original keystrokes seamlessly — this is the one thing that must work.

### Constraints

- **Platform**: macOS 13 Ventura+ (Apple Silicon + Intel) — uses modern SwiftUI and CGEventTap APIs
- **Dependencies**: Zero third-party dependencies — Apple frameworks only
- **Build**: Must be fully CLI-buildable (xcodegen + make) — no Xcode GUI required
- **Signing**: Ad-hoc signing only (no Apple Developer account) — personal distribution
- **Performance**: Chord detection must be imperceptible (<50ms from release to output)
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

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
## API Details by Feature
### CGEventTap — Keystroke Interception
### Text Output — CGEventPost
### Hot-Reload — DispatchSource
### MenuBarExtra — SwiftUI
## project.yml Skeleton
## Makefile Pattern
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
## Version Compatibility
| Component | Version | Compatible With | Notes |
|-----------|---------|-----------------|-------|
| `MenuBarExtra` | SwiftUI 4 | macOS 13.0+ | Introduced macOS 13; confirmed working macOS 13–15. Use `.menuBarExtraStyle(.menu)` for simple dropdown. |
| `CGEventTapCreate` | CoreGraphics | macOS 10.4+, still current macOS 15 | API stable; only the permission model tightened in macOS 12+. Always call `CGPreflightListenEventAccess()` before creating tap. |
| `DispatchSource.makeFileSystemObjectSource` | Foundation | macOS 10.10+ | Stable. Note: atomic-write editors rename files — must watch `.rename` in eventMask and re-open fd. |
| Swift concurrency (`async/await`, actors) | Swift 5.5+ | macOS 12+; macOS 13 for full back-deployment | Use actors to isolate chord state. CGEventTap callback runs on a non-main thread; bridge to actor with `Task { await actor.handle(event) }`. |
| XcodeGen | 2.45.4 | Xcode 16.x | Install via Homebrew: `brew install xcodegen`. |
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
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Build Commands

```bash
brew install xcodegen create-dmg   # prerequisites (one-time)
xcodegen generate                  # generates .xcodeproj from project.yml
make build                         # compiles → .app (ad-hoc signed)
make test                          # runs XCTest suite
make run                           # build + launch
make dmg                           # wraps .app into .dmg
make clean                         # remove build artifacts
```

Every phase must pass `make build && make test` before completion.

## File Responsibilities

| File | Responsibility |
|------|---------------|
| `Sources/ChordTyper/main.swift` | Entry point |
| `Sources/ChordTyper/AppDelegate.swift` | NSApplication + menubar setup |
| `Sources/ChordTyper/EventTap.swift` | CGEventTap setup and lifecycle |
| `Sources/ChordTyper/ChordDetector.swift` | Timing window + chord recognition |
| `Sources/ChordTyper/DictionaryManager.swift` | JSON loading, hot-reload, lookup |
| `Sources/ChordTyper/TextOutput.swift` | Key suppression + word output + smart space |
| `Sources/ChordTyper/SettingsView.swift` | SwiftUI settings window |
| `Sources/ChordTyper/AppListManager.swift` | Blacklist/whitelist management |
| `Resources/Info.plist` | App configuration (LSUIElement=YES) |
| `Resources/ChordTyper.entitlements` | Accessibility permissions |
| `Resources/dictionaries/english.json` | English chord dictionary (~150 words) |
| `Resources/dictionaries/thai.json` | Thai chord dictionary (~100 words) |
| `project.yml` | xcodegen project configuration |
| `Makefile` | Build/run/test/dmg targets |

## Coding Conventions

- **No force unwraps** (`!`) — use `guard let`, `if let`, or `??` with sensible defaults
- **Use `os.log`** for logging, never `print()` — `os.log` integrates with Console.app and can be filtered
- **Use `Result` type** for error handling in non-async code — makes error paths explicit
- **No third-party dependencies** — Apple frameworks only
- **Swift 6 strict concurrency** — use actors to isolate mutable state; no `@unchecked Sendable` hacks
- **CGEventTap callback must be minimal** — dispatch heavy work to a background queue, return immediately
- **Sorted-alphabetical key encoding** for chord keys — lowercase, sorted, used as dictionary lookup key

## Testing Conventions

- Every phase includes XCTest unit tests — no phase is complete without passing tests
- Test files live in `Tests/ChordTyperTests/`
- Test naming: `test[Component]_[scenario]_[expectedBehavior]` (e.g., `testChordDetector_threeKeysReleased_producesChordKey`)
- Test chord detection logic with synthetic key events (no real CGEventTap needed in tests)
- Test dictionary loading with fixture JSON files
- Test smart space logic with explicit input/output pairs
- Test app filter logic (blacklist/whitelist) with mock bundle identifiers
- Run `make test` after every change — CI-equivalent gate
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

### Event Processing Pipeline

```
Keyboard → CGEventTap (driver level, before IME)
  → AppFilter check (is this app allowed?)
  → SecureInputMonitor check (is secure input active?)
  → ChordDetector (collect keys, timing window, evaluate on all-keys-released)
  → DictionaryManager lookup (sorted-alpha key → word)
  → TextOutput (suppress originals, post word + smart space)
```

### Key Design Decisions

- **CGEventTap at `.cghidEventTap`** — intercepts below IME layer; Thai IME does not interfere
- **Evaluate on all-keys-released** — prevents false positives during chord formation
- **Sorted-alphabetical key encoding** — order-independent matching with O(1) dictionary lookup
- **NSPasteboard fallback for Thai** — CGEvent Unicode posting is unreliable in Electron apps
- **Synthetic event marking** — prevents re-entry into chord detection from our own output
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
