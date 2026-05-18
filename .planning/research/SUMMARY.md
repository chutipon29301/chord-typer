# Project Research Summary

**Project:** ChordTyper
**Domain:** macOS menubar utility — simultaneous chord-based typing with IME-transparent keystroke interception
**Researched:** 2026-05-18
**Confidence:** HIGH

## Executive Summary

ChordTyper is a macOS menubar utility that intercepts keystrokes at the HID driver level using `CGEventTap`, detects simultaneous key presses (chords), and replaces them with pre-defined words or phrases without requiring any third-party dependencies. The only public API capable of achieving this reliably — regardless of active input method, including Thai IME — is `CGEventTapCreate` at `.cghidEventTap`, which intercepts events before the IME layer. All alternative approaches (`NSEvent`, Carbon, `AXObserver`) operate above the IME and cannot suppress events, making them unfit for this use case. The recommended stack is Swift 6.1 + SwiftUI 5 + CoreGraphics, built with xcodegen and a simple Makefile, targeting macOS 13+.

The architecture follows a clear layered separation: a CGEventTap-based event pipeline on a background thread, a stateful chord detection engine, a hot-reloadable dictionary layer, and a SwiftUI menubar UI layer that only reads shared state. All chord detection logic must execute synchronously inside the tap callback (never dispatched async) to avoid timeout-induced tap disablement. For text output, ASCII words use `CGEvent` Unicode posting directly, but Thai Unicode characters must use NSPasteboard + Cmd-V injection because many apps (Electron, terminal emulators) ignore the Unicode string payload in synthetic keyboard events.

The top risk is the TCC identity invalidation pattern: every rebuild invalidates the app's code-signing identity, causing macOS to silently disable the CGEventTap with no error. This and three other failure modes (sleep/wake tap disablement, stale key-down state, and callback blocking leading to timeout) are non-obvious and have caused real production regressions in apps like Ghostty and Wispr Flow. All four must be addressed as first-class concerns in the event tap scaffold phase, not retrofitted later.

## Key Findings

### Recommended Stack

The entire project is achievable with Apple-native frameworks only — no third-party dependencies. `CGEventTap` at `.cghidEventTap` is the only API that intercepts below the IME; `MenuBarExtra` (SwiftUI, macOS 13+) provides the canonical menubar UI without AppKit boilerplate; `DispatchSource.makeFileSystemObjectSource` provides lightweight file watching for hot-reload; and `CGEvent` Unicode string posting (with NSPasteboard fallback for Thai) handles text output. xcodegen + Make replaces the Xcode GUI for builds, making the project CLI-reproducible. App Sandbox must be omitted because sandboxed apps cannot use `CGEventPost` to inject synthetic events.

**Core technologies:**
- Swift 6.1: Primary language — strict concurrency catches data races in event tap callbacks at compile time
- CoreGraphics / CGEventTap at `.cghidEventTap`: Keystroke interception — the only API below the IME layer; alternatives (NSEvent, Carbon) are disqualified
- SwiftUI 5 / MenuBarExtra: Menubar UI — macOS 13+ native API, no AppKit NSStatusItem boilerplate needed
- Foundation / DispatchSource: Hot-reload file watching — simpler than FSEvents for watching 2 specific JSON files
- AppKit (minimal) / NSPasteboard: Thai Unicode output fallback — required because CGEventKeyboardSetUnicodeString is unreliable in Electron and terminal apps
- xcodegen 2.45.4 + Make: Build system — eliminates .xcodeproj merge conflicts; SPM cannot express CGEventTap entitlements

### Expected Features

All features in the v1 MVP are P1 — they all belong in the initial launch and are tightly interdependent. The feature dependency chain flows from permission detection to tap activation to chord detection to text output; no step can be skipped.

**Must have (table stakes):**
- CGEventTap with Accessibility permission detection and guided prompt — tap silently fails without this
- Chord detection: timing window (50ms default, 20-200ms configurable), key-order-independent, evaluate on all-keys-released
- Unmatched chord pass-through — replay suppressed keys in original order; without this, users lose keystrokes
- JSON dictionary loading (English ~150 words, Thai ~100 words) with hot-reload
- Text output: key suppression + word expansion + smart space (append after chord, strip before punctuation)
- Per-app blacklist/whitelist by bundle ID — collision with IDE/game shortcuts makes this essential
- Secure input passthrough — graceful state flush when CGEventTap goes silent
- Menubar icon with active/paused state, global toggle (Cmd+Shift+Space), quit item
- Settings window: timing slider, dictionary toggles, app filter, shortcut display
- Ad-hoc signed DMG via `make dmg`

**Should have (competitive):**
- IME-transparent keystroke interception via `.cghidEventTap` — primary differentiator vs. ZipChord/Plover which use higher-level APIs and fail with Thai IME
- Thai-language chord dictionary — no existing chord app targets Thai; requires QWERTY key code to Thai Unicode mapping
- ZipChord-compatible English chord assignments — lowers switching cost from Windows
- CLI-buildable via xcodegen + Makefile — reproducible builds without Xcode GUI

**Defer (v2+):**
- Launch at login — add only after the app is stable enough for daily background use
- In-app chord editor / CRUD dictionary UI — 3-5x the UI complexity; JSON + hot-reload is sufficient for technical users
- Chord hints overlay / visualizer — requires separate window layer, z-order management; low value once chords are learned
- Typing statistics — does not improve chord reliability; deferred post-launch
- Cloud sync — requires CloudKit entitlements and Apple Developer account; personal use on one Mac

### Architecture Approach

The architecture is a linear pipeline with three isolated layers: (1) an event pipeline layer (EventTapManager + ChordEngine) running on a dedicated background thread run loop, (2) a dictionary layer (DictionaryStore + DictionaryWatcher + DictionaryLoader) with atomic swap on reload, and (3) an AppKit/SwiftUI UI layer (MenuBarController + SettingsView + PermissionGuideView) that only reads observable state from AppState on the main actor. The ChordEngine implements a state machine over three pieces of state: `heldKeys: Set<CGKeyCode>`, `bufferedEvents: [(CGEvent, timestamp)]`, and `chordWindow: TimeInterval`. Events are suppressed on keyDown and replayed or replaced on all-keys-released. The gate check order before chord evaluation is: (1) AppState.isActive, (2) AppFilter.isAllowed(bundleID), (3) SecureInputMonitor.isSecure — in that order on every event.

**Major components:**
1. `EventTapManager` — owns CGEventTap lifecycle: create, background thread run loop, health-check timer (5s), re-enable on timeout/user-input disable events
2. `ChordEngine` — stateful chord detection state machine: buffer on keyDown, evaluate on all-keys-released, suppress or replay
3. `DictionaryStore` / `DictionaryWatcher` — in-memory [String:String] with sorted-alpha key encoding; DispatchSource file watcher for hot-reload with atomic swap
4. `AppFilter` + `SecureInputMonitor` — gate conditions evaluated before every chord lookup; AppFilter reads cached bundle ID from NSWorkspace notification (never calls into AppKit from the callback thread)
5. `EventOutputter` — synthesizes CGEvent Unicode output; dispatches asynchronously (never from inside the tap callback to avoid re-entry loops)
6. `AppState` — @MainActor ObservableObject holding all settings; components read it on their own thread (eventual consistency acceptable for settings)
7. `MenuBarController` + `SettingsView` + `PermissionGuideView` — pure UI layer with zero imports of Core/

### Critical Pitfalls

1. **TCC silent disable after rebuild** — CGEventTapCreate returns non-nil but the tap is inert because the code-signing identity changed. Prevent with: CGPreflightListenEventAccess() before tap creation, a 1-second post-install tapIsEnabled check, and a 5-second repeating health-check timer. During development, add `tccutil reset Accessibility <bundleid>` to the Makefile run target.

2. **Sleep/wake and screen-lock tap disablement** — tap stops silently after sleep; no crash, no log. Prevent with: handle kCGEventTapDisabledByTimeout and kCGEventTapDisabledByUserInput in the callback by re-enabling immediately; register for NSWorkspace.didWakeNotification to reinstall the tap; the 5-second health-check timer serves as catch-all recovery.

3. **Stale key-down state causing stuck keys and phantom chords** — a missed key-up leaves a key permanently in keysDown, causing all subsequent keypresses to look like chords (the Wispr Flow spacebar bug). Prevent with: process all key state mutations synchronously in the callback (no async dispatch for state), unconditionally clear keysDown before each evaluation, and add a 2-second stale-key eviction timer.

4. **Thai Unicode output unreliable via CGEventKeyboardSetUnicodeString** — works in TextEdit, silently wrong in VS Code and iTerm2 because Electron/terminal apps re-derive characters from the virtual keycode. Prevent by designing dual output from the start: keyCode-based events for ASCII, NSPasteboard + Cmd-V injection for Thai Unicode.

5. **Tap callback blocking causing kCGEventTapDisabledByTimeout** — any blocking operation (I/O, synchronous dispatch, os_log) inside the callback stalls the event pipeline. Prevent by keeping the callback under 1ms: pre-load dictionaries into memory, dispatch only UI updates to main, never do file I/O in the callback path.

## Implications for Roadmap

Based on research, the build dependency graph from ARCHITECTURE.md directly maps to phase ordering. Layers 1-6 in the dependency graph (DictionaryStore through ChordEngine) are unit-testable without a running menubar app. The event tap scaffold must be built and hardened before feature work depends on it, because all pitfalls compound if tap lifecycle management is retrofitted.

### Phase 1: Project Scaffold and Event Tap Core

**Rationale:** Everything else depends on a working, resilient CGEventTap. The TCC silent-disable pitfall, sleep/wake disablement, and callback discipline must be established here — they cannot be retrofitted. This phase has the highest risk.
**Delivers:** A buildable macOS app skeleton with a functioning CGEventTap on a background thread, health-check timer, re-enable logic, and permission detection with guided UI. No chord detection yet — just raw event logging to confirm the tap works across rebuilds, sleep/wake cycles, and Finder launches.
**Addresses:** Accessibility permission detection, LSUIElement menubar-only app, @main + AppDelegate wiring, xcodegen project structure
**Avoids:** Pitfalls 1 (TCC), 2 (sleep/wake), 5 (callback blocking)
**Research flag:** Standard patterns — CGEventTap lifecycle is well-documented in Apple docs and production open-source apps (alt-tab-macos). No additional research needed.

### Phase 2: Chord Detection State Machine

**Rationale:** ChordEngine is the core algorithmic component. Its state machine design (buffer, evaluate, suppress, replay) must be correct before dictionary integration. Building it in isolation allows unit testing with synthetic CGEvents without needing a real tap.
**Delivers:** ChordEngine with correct state machine: keyDown buffering (suppress), all-keys-released evaluation, timing window enforcement, key-order-independent sorted-alpha encoding, unmatched pass-through replay.
**Implements:** ChordEngine, EventOutputter (ASCII path only)
**Avoids:** Pitfall 3 (stale key-down state), Anti-Pattern 2 (evaluating on keyDown), Anti-Pattern 3 (re-posting from inside callback)
**Research flag:** Standard patterns — the state machine is fully specified in ARCHITECTURE.md. No additional research needed.

### Phase 3: Dictionary Layer and Thai Unicode Output

**Rationale:** DictionaryStore and DictionaryLoader have zero dependencies and can be built before or alongside Phase 2, but they are separated here because Thai Unicode output requires a distinct output strategy that must be confirmed to work before shipping.
**Delivers:** JSON dictionary loading with sorted-alpha key normalization, DispatchSource hot-reload watcher with atomic swap, English (~150 words) and Thai (~100 words) chord dictionaries, dual output strategy (CGEvent for ASCII, NSPasteboard + Cmd-V for Thai), smart space management.
**Uses:** DispatchSource.makeFileSystemObjectSource, JSONDecoder, NSPasteboard
**Avoids:** Pitfall 4 (Thai Unicode via CGEventKeyboardSetUnicodeString), hot-reload re-entry race condition
**Research flag:** Thai output strategy needs validation. Test NSPasteboard + Cmd-V injection in VS Code (Electron), iTerm2, Terminal, and Safari before finalizing. The clipboard-restore flow when clipboard managers (Paste, Raycast) are running adds timing complexity not fully resolved in research.

### Phase 4: App Filter, Secure Input, and Gate Logic

**Rationale:** Per-app filtering and secure input detection are gate conditions that must be checked before every chord lookup. Both use similar patterns (cached state read on callback thread, updated via notifications or timers) and both affect the same code path.
**Delivers:** AppFilter (NSWorkspace notification → cached bundle ID, blacklist/whitelist check), SecureInputMonitor (IsSecureEventInputEnabled() polling at 1-second interval), visual state in menubar icon for paused-by-secure-input state.
**Avoids:** Pitfall 6 (secure input stuck on), NSWorkspace call inside callback, stale bundle ID state
**Research flag:** Standard patterns — NSWorkspace notifications and IsSecureEventInputEnabled() polling are documented and used by Keyboard Maestro, TextExpander. No additional research needed.

### Phase 5: Menubar UI, Settings, and Global Toggle

**Rationale:** UI is built last because it only reads AppState — it has no effect on the event pipeline. Settings changes propagate via AppState without restarting the tap. This phase completes the MVP.
**Delivers:** MenuBarExtra with active/paused/secure-input icon states, dropdown menu (toggle, pause for current app, open settings, quit), SwiftUI settings window (timing slider, dictionary toggles, per-app filter list, shortcut display), global toggle shortcut (Cmd+Shift+Space), ad-hoc signed DMG via `make dmg`.
**Uses:** MenuBarExtra, SwiftUI Settings scene, hdiutil, codesign -s -
**Avoids:** Dock icon appearing (LSUIElement = YES), shortcut conflict with Spotlight language toggle (make shortcut configurable)
**Research flag:** Standard patterns — MenuBarExtra is fully documented. No additional research needed.

### Phase Ordering Rationale

- The event tap must be hardened before anything depends on it (Phase 1 first) because TCC, sleep/wake, and callback discipline failures are invisible and compound silently.
- ChordEngine (Phase 2) is built before dictionaries (Phase 3) so the state machine can be validated with synthetic inputs before adding real dictionary lookups.
- Dictionary and Thai output (Phase 3) is isolated because the dual output strategy for Thai requires explicit validation across target apps before integration into the chord engine.
- App filter and secure input (Phase 4) are pure gate conditions with no UI dependencies; they slot between the core pipeline and the UI phase.
- UI (Phase 5) is last because it is the only layer with no dependencies from below it — every other component exposes state via AppState that the UI reads.

### Research Flags

Phases needing deeper research during planning:
- **Phase 3:** Thai Unicode output via NSPasteboard + Cmd-V injection needs app-by-app validation. Clipboard-capture-and-restore timing with clipboard managers running is unresolved.

Phases with standard patterns (skip research-phase during planning):
- **Phase 1:** CGEventTap lifecycle, TCC permission prompts, background thread run loop — fully documented with production references.
- **Phase 2:** Chord state machine design is fully specified in ARCHITECTURE.md with code examples.
- **Phase 4:** NSWorkspace notifications and IsSecureEventInputEnabled() polling — standard, widely-used patterns.
- **Phase 5:** MenuBarExtra, SwiftUI Settings, hdiutil DMG creation — standard Apple patterns.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All APIs are Apple-native with official documentation; no third-party dependencies to vet; xcodegen version confirmed current |
| Features | HIGH (core), MEDIUM (UX) | Table stakes and P1 features are well-defined; smart space edge cases and per-app filter UX patterns are community-consensus-based |
| Architecture | HIGH | Component responsibilities, data flow, and build order verified against Apple docs and production open-source apps (alt-tab-macos) |
| Pitfalls | HIGH | All 6 critical pitfalls cross-verified with real production failures (Ghostty, Wispr Flow, Keyboard Maestro, TextExpander); not speculative |

**Overall confidence:** HIGH

### Gaps to Address

- **Thai Unicode output in clipboard-manager environments:** NSPasteboard injection works in isolation but the clipboard-capture-before / clipboard-restore-after flow has timing risks when Paste, Raycast, or other clipboard managers are watching NSPasteboard. Validate during Phase 3 implementation. If clipboard restore proves unreliable, consider a dedicated output pasteboard (NSPasteboard(name:)) or a brief NSPasteboard change suppression signal.
- **Synthetic event re-entry loop prevention:** The recommended approach is marking synthetic events with a custom eventSourceUserData flag (0xCH0RD) and skipping them in the callback. This needs an explicit implementation test to confirm the flag survives the event pipeline and is readable inside the tap callback at .cghidEventTap level.
- **Cmd+Shift+Space toggle shortcut conflict:** This shortcut collides with Spotlight's "Switch to previous input source" in some system configurations. Making the shortcut user-configurable from day one avoids the conflict.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: CGEventTapCreate, CGEvent.tapEnable, CGEvent.init(keyboardEventSource:virtualKey:keyDown:), DispatchSource, NSWorkspace.frontmostApplication
- Swift.org: Swift 6.1 Released — current language version
- xcodereleases.com — Xcode 16.4 with Swift 6.1
- Context7 / XcodeGen /yonaskolb/xcodegen — project.yml spec, version 2.45.4
- alt-tab-macos KeyboardEvents.swift — production CGEventTap reference implementation

### Secondary (MEDIUM confidence)
- nilcoalescing.com: Build a macOS menu bar utility in SwiftUI — MenuBarExtra patterns
- swiftrocks.com: DispatchSource file watching — event mask selection, atomic-write pattern
- Daniel Raffel: CGEvent Taps and Code Signing (2026) — TCC silent-disable race documentation
- Ghostty discussion #11819 — sleep/wake tap disablement production failure
- Wensen Wu: How Wispr Flow Ate My Spacebar — stale key-down state forensic case study
- Keyboard Maestro Wiki: Secure Input Problem — SKE stuck-on failure modes
- ZipChord GitHub / author overview / HN discussion — feature comparison, chord model reference

### Tertiary (needs validation during implementation)
- Apple Developer Forums thread #706245 — CGEventPost with Thai Unicode characters, mixed reports on reliability across app types
- Feedback Assistant report #390 — CGEventTap event loss pattern, not officially acknowledged

---
*Research completed: 2026-05-18*
*Ready for roadmap: yes*
