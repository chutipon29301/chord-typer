# Architecture Research

**Domain:** macOS keyboard interception / chord-based typing menubar app
**Researched:** 2026-05-18
**Confidence:** HIGH (CGEventTap, DispatchSource, NSWorkspace patterns all verified against official Apple docs and production open-source apps)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AppKit / SwiftUI Layer                       │
│                                                                       │
│  ┌─────────────┐  ┌────────────────┐  ┌──────────────────────────┐  │
│  │ NSStatusItem│  │ Settings Window│  │  Permission Guide Window  │  │
│  │  (menubar)  │  │  (SwiftUI)     │  │  (Accessibility prompt)  │  │
│  └──────┬──────┘  └───────┬────────┘  └────────────┬─────────────┘  │
│         │                 │                         │                │
├─────────┴─────────────────┴─────────────────────────┴────────────────┤
│                         Application Core                              │
│                                                                       │
│  ┌──────────────────┐   ┌───────────────┐   ┌─────────────────────┐ │
│  │  AppState        │   │ AppFilter     │   │ SecureInputMonitor  │ │
│  │  (ObservableObj) │   │ (NSWorkspace  │   │ (IsSecureEvent-     │ │
│  │  active/paused   │   │  notifications│   │  InputEnabled poll) │ │
│  │  settings        │   │  + bundleID   │   │                     │ │
│  └──────┬───────────┘   └───────┬───────┘   └──────────┬──────────┘ │
│         │                       │                       │            │
├─────────┴───────────────────────┴───────────────────────┴────────────┤
│                         Event Pipeline                                │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  EventTapManager                                              │    │
│  │  - CFMachPort (CGEventTap)                                   │    │
│  │  - CFRunLoopSource on background thread run loop             │    │
│  │  - Re-enable on tapDisabledByTimeout / tapDisabledByUserInput│    │
│  │  - Health-check timer (5-second interval)                    │    │
│  └──────────────────────────┬───────────────────────────────────┘    │
│                             │ raw CGEvents                           │
│  ┌──────────────────────────▼───────────────────────────────────┐    │
│  │  ChordEngine                                                  │    │
│  │  - keyDown: buffer key + timestamp                            │    │
│  │  - keyUp: update held-key set                                 │    │
│  │  - all-keys-released: evaluate, sort, lookup                 │    │
│  │  - match: suppress all buffered events, emit replacement      │    │
│  │  - no-match: replay buffered events unchanged                 │    │
│  └──────────────────────────┬───────────────────────────────────┘    │
│                             │                                        │
├─────────────────────────────┴────────────────────────────────────────┤
│                         Dictionary Layer                              │
│                                                                       │
│  ┌───────────────────┐   ┌───────────────────┐                       │
│  │ DictionaryStore   │   │ DictionaryWatcher  │                      │
│  │ - [String:String] │◄──│ - DispatchSource   │                      │
│  │   sorted-alpha    │   │   .makeFileSys...  │                      │
│  │   key → word      │   │ - .write eventMask │                      │
│  │ - O(1) lookup     │   │ - reload on change │                      │
│  └───────────────────┘   └───────────────────┘                       │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `AppDelegate` | Bootstraps app: creates NSStatusItem, installs tap, wires dependencies | All components |
| `AppState` | Observable shared state: active/paused flag, global shortcut, settings | UI, EventTapManager, ChordEngine, AppFilter |
| `EventTapManager` | Owns CGEventTap lifecycle: create, install, health-check, re-enable | ChordEngine (delivers events), AppState (enable/disable gate) |
| `ChordEngine` | Stateful chord detection: buffer keys, detect all-released, lookup, suppress or replay | DictionaryStore (lookup), EventOutputter (emit replacement) |
| `EventOutputter` | Synthesizes CGEvent keystrokes to type the matched word + smart space | ChordEngine (called on match) |
| `DictionaryStore` | In-memory map of sorted-alpha-key → word. Swappable per language | ChordEngine (read), DictionaryWatcher (writes) |
| `DictionaryWatcher` | DispatchSource file watcher; reloads DictionaryStore on JSON write | DictionaryStore |
| `AppFilter` | Tracks frontmost app via NSWorkspace notifications; gates ChordEngine | ChordEngine, AppState (whitelist/blacklist config) |
| `SecureInputMonitor` | Polls `IsSecureEventInputEnabled()`; signals ChordEngine to pass-through | ChordEngine |
| `NSStatusItem` | Menubar icon + dropdown; reflects AppState.active | AppState |
| `SettingsWindow` | SwiftUI settings: timing slider, dictionary toggles, app filter list | AppState |
| `PermissionGuide` | Detects missing Accessibility/Input Monitoring; shows onboarding UI | AppDelegate (on launch check) |

## Recommended Project Structure

```
Sources/ChordTyper/
├── App/
│   ├── ChordTyperApp.swift      # @main, @NSApplicationDelegateAdaptor
│   └── AppDelegate.swift        # applicationDidFinishLaunching, wires all components
│
├── Core/
│   ├── AppState.swift           # @MainActor ObservableObject — settings & active flag
│   ├── EventTapManager.swift    # CGEventTap create/install/health-check/re-enable
│   ├── ChordEngine.swift        # Stateful chord detection, suppress/replay logic
│   └── EventOutputter.swift     # CGEvent synthesis — types expanded word
│
├── Dictionary/
│   ├── DictionaryStore.swift    # [String:String] in-memory map, thread-safe reads
│   ├── DictionaryWatcher.swift  # DispatchSource file watcher → triggers reload
│   └── DictionaryLoader.swift   # JSON parsing, sorted-alpha key normalization
│
├── Filter/
│   ├── AppFilter.swift          # NSWorkspace notification subscriber, bundle ID gate
│   └── SecureInputMonitor.swift # Polls IsSecureEventInputEnabled(), timer-based
│
├── UI/
│   ├── MenuBarController.swift  # NSStatusItem + NSMenu setup, icon state
│   ├── SettingsView.swift       # SwiftUI settings window
│   └── PermissionGuideView.swift# Accessibility/InputMonitoring onboarding
│
└── Dictionaries/
    ├── english.json             # ZipChord-compatible sorted-alpha chords
    └── thai.json                # QWERTY key codes → Thai Unicode words
```

### Structure Rationale

- **Core/**: The event pipeline is the most critical path; keeping it separate from UI makes it testable without the full app running.
- **Dictionary/**: Isolated so DictionaryStore can be replaced (e.g., binary format) without touching Core.
- **Filter/**: AppFilter and SecureInputMonitor are both gate conditions; grouping them clarifies that ChordEngine only fires when both pass.
- **UI/**: All AppKit/SwiftUI surface lives here; Core has zero UIKit/SwiftUI imports.

## Architectural Patterns

### Pattern 1: Event Tap on Background Thread, Dispatch to Main

**What:** CGEventTap callback runs on a dedicated background thread run loop. Heavy logic (chord detection) executes in the callback thread. UI updates are dispatched to `DispatchQueue.main.async`.

**When to use:** Always. CGEventTap callbacks must be fast and non-blocking. The main thread may stall; putting the tap source on a background run loop ensures responsiveness.

**Trade-offs:** Thread safety becomes explicit — ChordEngine state must either be actor-isolated or protected by a lock. The alt-tab-macos open-source app uses this pattern in production.

**Example:**
```swift
// EventTapManager.swift
let thread = Thread { RunLoop.current.run() }
thread.start()

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(thread.runLoop, source, .commonModes)
```

### Pattern 2: Opaque Pointer Self-Reference in C Callback

**What:** CGEventTap callback is a C function pointer — it cannot close over `self`. Pass `self` as `UnsafeMutableRawPointer` via the `userInfo` parameter and unpack it inside the callback.

**When to use:** Required whenever the tap callback needs to call instance methods.

**Trade-offs:** The instance must be retained for the tap's lifetime (store the tap manager as a strong reference in AppDelegate). Mismanagement causes use-after-free crashes.

**Example:**
```swift
let userInfo = Unmanaged.passUnretained(self).toOpaque()

CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: mask,
    callback: { proxy, type, event, info -> Unmanaged<CGEvent>? in
        let engine = Unmanaged<EventTapManager>.fromOpaque(info!).takeUnretainedValue()
        return engine.handle(proxy: proxy, type: type, event: event)
    },
    userInfo: userInfo
)
```

### Pattern 3: Active Tap Health Monitoring

**What:** A non-nil return from `CGEvent.tapCreate` does not guarantee the tap works. Code signing re-evaluation, permission changes, and system timeouts can silently disable the tap. Schedule a repeating timer (5-second interval) that calls `CGEvent.tapIsEnabled(tap:)` and re-enables or reinstalls on failure.

**When to use:** Always in production; omitting this makes the app appear frozen after sleep/wake or permission prompts.

**Trade-offs:** Minor CPU overhead from polling, worth it for reliability.

**Example:**
```swift
// Handle in callback
if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    CGEvent.tapEnable(tap: self.tap, enable: true)
    return nil
}

// Health-check timer
Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
    guard let self, !CGEvent.tapIsEnabled(tap: self.tap) else { return }
    self.reinstall()
}
```

### Pattern 4: Chord Detection State Machine

**What:** ChordEngine maintains three pieces of state: `heldKeys: Set<CGKeyCode>`, `bufferedEvents: [(CGEvent, timestamp: CFAbsoluteTime)]`, and `chordWindow: TimeInterval`. On `keyDown`, add to both. On `keyUp`, remove from `heldKeys`. When `heldKeys` becomes empty (all released), evaluate: if 3+ keys were involved and all fell within the chord window, attempt a lookup; otherwise replay buffered events.

**When to use:** This is the only correct evaluation trigger for ChordTyper. Evaluating on keyDown causes false positives mid-chord.

**Trade-offs:** Holding the chord window open means a small delay before characters appear for unmatched chords. Configurable 20–200ms range lets users tune the tradeoff.

**Example:**
```swift
// Sorted-alpha key encoding for order-independent O(1) lookup
func chordKey(from keyCodes: [CGKeyCode]) -> String {
    keyCodes.map { keyCodeToChar($0) }.sorted().joined()
}
// "T+H+E" == "E+H+T" == "H+E+T" → always "eht"
```

### Pattern 5: Event Suppression vs. Replay

**What:** When a chord matches, return `nil` from the callback for all buffered keyDown/keyUp events (suppression). Then synthesize fresh CGEvents for the expanded word. When no match, the buffered events were already passed through during collection — do not re-send them (double-input bug).

**Critical detail:** Use `.headInsertEventTap` with `.defaultTap` (not `.listenOnly`) so the callback can return `nil` to suppress. A listenOnly tap cannot suppress events.

**Trade-offs:** `.defaultTap` requires Accessibility permission in addition to Input Monitoring.

**Example:**
```swift
// Synthesize replacement after suppression
for char in expandedWord {
    let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
    keyDown?.keyboardSetUnicodeString(string: String(char))
    keyDown?.post(tap: .cgAnnotatedSessionEventTap)
    let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
    keyUp?.keyboardSetUnicodeString(string: String(char))
    keyUp?.post(tap: .cgAnnotatedSessionEventTap)
}
```

### Pattern 6: Dictionary Hot-Reload via DispatchSource

**What:** Open the JSON file with a `FileHandle`. Create a `DispatchSourceFileSystemObject` watching `.write` events. In the event handler, reload the file and swap the dictionary atomically. Cancel the source in `deinit`.

**When to use:** Required for the hot-reload requirement; avoids polling and is zero-overhead when the file is not written.

**Trade-offs:** DispatchSource `.write` fires on file-descriptor extension (append). For full overwrite (text editor save), also watch `.rename` or use FSEventStream. The simpler DispatchSource approach covers most editors; FSEventStream covers atomic-save editors (Vim, BBEdit).

**Example:**
```swift
source = DispatchSource.makeFileSystemObjectSource(
    fileDescriptor: fileHandle.fileDescriptor,
    eventMask: [.write, .rename],
    queue: DispatchQueue.global(qos: .utility)
)
source.setEventHandler { [weak self] in self?.reload() }
source.resume()
```

## Data Flow

### Keystroke Interception and Chord Expansion

```
Physical Keypress (HW)
    │
    ▼
CGEventTap callback (background thread run loop)
    │
    ├─ Gate 1: AppState.isActive? → NO → pass event through unchanged
    ├─ Gate 2: AppFilter.isAllowed(bundleID)? → NO → pass event through
    ├─ Gate 3: SecureInputMonitor.isSecure? → YES → pass event through
    │
    ▼ (all gates pass)
ChordEngine.handle(event)
    │
    ├─ keyDown → add to heldKeys + bufferedEvents, return nil (suppress)
    ├─ keyUp → remove from heldKeys
    │       └─ heldKeys empty? → evaluate chord
    │               ├─ 3+ keys within chord window?
    │               │   ├─ DictionaryStore.lookup(sortedKey) → hit
    │               │   │   └─ EventOutputter.type(word + smart-space)
    │               │   └─ miss → replay buffered events (resend suppressed)
    │               └─ <3 keys or outside window → replay buffered events
    └─ other event types → pass through
```

### Dictionary Hot-Reload

```
User edits english.json (text editor save)
    ↓
DictionaryWatcher (DispatchSource .write/.rename fires)
    ↓
DictionaryLoader.load(url) → parses JSON, normalizes keys to sorted-alpha
    ↓
DictionaryStore.swap(newDict) → atomic replace (actor or lock)
    ↓
ChordEngine reads updated store on next lookup (no restart needed)
```

### App Filter Update

```
User switches active app (e.g., Terminal → Chrome)
    ↓
NSWorkspace.didActivateApplicationNotification
    ↓
AppFilter receives notification → reads bundleIdentifier
    ↓
Checks against AppState.blacklist / AppState.whitelist
    ↓
Sets AppFilter.isAllowed (read by EventTapManager gate check)
```

### Settings Change

```
User moves timing slider in SettingsView
    ↓
Binding → AppState.chordWindow = newValue (on MainActor)
    ↓
ChordEngine reads AppState.chordWindow on next evaluation
(no restart needed — ChordEngine references AppState directly)
```

## Build Order (Dependency Graph)

Build in this order — each layer depends only on layers above it:

```
1. DictionaryStore          (no dependencies — pure value type)
2. DictionaryLoader         (depends on: DictionaryStore)
3. DictionaryWatcher        (depends on: DictionaryLoader, DictionaryStore)
4. AppState                 (depends on: nothing — foundation of shared state)
5. EventOutputter           (depends on: CoreGraphics only)
6. ChordEngine              (depends on: DictionaryStore, AppState, EventOutputter)
7. AppFilter                (depends on: AppState, AppKit/NSWorkspace)
8. SecureInputMonitor       (depends on: CoreGraphics/Carbon)
9. EventTapManager          (depends on: ChordEngine, AppFilter, SecureInputMonitor, AppState)
10. MenuBarController       (depends on: AppState, EventTapManager)
11. SettingsView            (depends on: AppState)
12. PermissionGuideView     (depends on: AppState)
13. AppDelegate             (depends on: everything — wires it all together)
```

This order means: you can build and unit-test layers 1–6 completely without a running menubar app. The event pipeline becomes testable by feeding synthetic CGEvents to ChordEngine without needing a real EventTapManager.

## Anti-Patterns

### Anti-Pattern 1: listenOnly Tap for Chord Interception

**What people do:** Create the tap with `.listenOnly` options to avoid requesting Accessibility permission, planning to suppress events "later".

**Why it's wrong:** `listenOnly` taps cannot return `nil` to suppress events. The option is compile-time valid but runtime no-op for suppression. Chords will be intercepted AND the original keystrokes will reach the app simultaneously.

**Do this instead:** Use `.defaultTap` with `.headInsertEventTap`. Handle the Accessibility permission request on first launch with a clear PermissionGuideView explaining why it is needed.

### Anti-Pattern 2: Evaluating Chord on keyDown

**What people do:** Check for chord match when each key goes down, to minimize latency.

**Why it's wrong:** The system has no way to know whether the user is still pressing additional keys to complete a chord. "T" keydown looks like a solo keystroke until "H" arrives. Evaluating early causes partial matches and incorrect suppression.

**Do this instead:** Buffer all keyDown events (suppressed). Evaluate when `heldKeys` empties. Accept the ~50ms delay — it is imperceptible for word-level output.

### Anti-Pattern 3: Re-posting Suppressed Events from the Tap Callback

**What people do:** Buffer events, then in the callback on the final keyUp, synchronously re-post buffered events via `CGEvent.post()`.

**Why it's wrong:** Posting from inside the tap callback re-enters the tap, causing infinite loops or dropped events. The tap callback stack is on the run loop — posting events that re-trigger the same tap is undefined behavior.

**Do this instead:** Mark buffered events for replay. After the callback returns, post them from outside the callback (e.g., via a DispatchQueue or by returning them via the Mach port mechanism). Alternatively, for unmatched chords, pass events through by returning the original event rather than `nil` in the first place — only suppress if you are confident a chord is forming.

### Anti-Pattern 4: Main Thread Run Loop for Event Tap

**What people do:** Add the tap's CFRunLoopSource to `CFRunLoopGetMain()` for simplicity.

**Why it's wrong:** The main thread also drives AppKit UI. Any UI work (animations, window updates) blocks the main run loop and delays event processing. Under load, the tap times out (`tapDisabledByTimeout`) and stops working.

**Do this instead:** Create a dedicated background thread running its own `RunLoop`. Install the tap source on that run loop. UI callbacks are dispatched to `DispatchQueue.main` explicitly.

### Anti-Pattern 5: fire-and-forget tap install

**What people do:** Call `CGEvent.tapCreate()` once, check for nil, and assume it works forever.

**Why it's wrong:** Code signing events, permission revocations, and sleep/wake cycles silently disable the tap. The app appears to work (no crash) but stops intercepting events.

**Do this instead:** Implement a health-check timer. In the callback, handle `.tapDisabledByTimeout` and `.tapDisabledByUserInput` by re-enabling immediately. If re-enable fails, reinstall the tap from scratch.

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| EventTapManager → ChordEngine | Direct method call in callback thread | ChordEngine must be thread-safe (Swift actor recommended) |
| ChordEngine → DictionaryStore | Direct read (lookup) | DictionaryStore swap must be atomic — use actor or `os_unfair_lock` |
| DictionaryWatcher → DictionaryStore | Dispatch to utility queue, then atomic swap | Do not block the watcher queue |
| AppFilter → ChordEngine | Shared flag read on callback thread | Bool read is atomic on ARM; use `@Atomic` wrapper for clarity |
| AppState → All components | @MainActor ObservableObject; components read on their own thread | Settings are read-only during event processing — eventual consistency is fine |
| MenuBarController → AppState | SwiftUI binding / Combine subscriber on MainActor | Standard SwiftUI pattern |
| EventOutputter → CoreGraphics | `CGEvent.post(tap: .cgAnnotatedSessionEventTap)` | Must not be called from inside the tap callback — post asynchronously |

### System Integrations

| System API | Integration Pattern | Notes |
|------------|---------------------|-------|
| CGEventTap (CoreGraphics) | `CGEvent.tapCreate` + CFMachPort + CFRunLoopSource | Requires Accessibility + Input Monitoring entitlements |
| DispatchSource (Foundation) | `makeFileSystemObjectSource` on utility queue | One watcher per dictionary file |
| NSWorkspace (AppKit) | `notificationCenter.addObserver` for `didActivateApplicationNotification` | Delivers on main queue by default |
| IsSecureEventInputEnabled (Carbon) | Timer-based polling every 500ms | Cannot receive a notification for this — polling is the only option |
| NSStatusItem (AppKit) | Created in `AppDelegate.applicationDidFinishLaunching` | Set `LSUIElement = YES` in Info.plist to suppress Dock icon |
| CGEvent synthesis (CoreGraphics) | `CGEvent(keyboardEventSource:virtualKey:keyDown:)` + `keyboardSetUnicodeString` | Use unicode string API, not virtual key codes, to handle Thai/non-ASCII correctly |

## Sources

- Apple Developer Documentation — CGEvent: https://developer.apple.com/documentation/coregraphics/cgevent
- Apple Developer Documentation — NSWorkspace.frontmostApplication: https://developer.apple.com/documentation/appkit/nsworkspace/frontmostapplication
- Apple Developer Documentation — DispatchSource.FileSystemEvent: https://developer.apple.com/documentation/dispatch/dispatchsource/filesystemevent
- Apple TN2150 — Using Secure Event Input Fairly: https://developer.apple.com/library/archive/technotes/tn2150/_index.html
- Daniel Raffel — CGEvent Taps and Code Signing (2026): https://danielraffel.me/til/2026/02/19/cgevent-taps-and-code-signing-the-silent-disable-race/
- SwiftRocks — DispatchSource: Detecting changes in files: https://swiftrocks.com/dispatchsource-detecting-changes-in-files-and-folders-in-swift
- alt-tab-macos KeyboardEvents.swift (production CGEventTap example): https://github.com/lwouis/alt-tab-macos/blob/master/src/logic/events/KeyboardEvents.swift
- Igor Kulman — Implementing Auto-Type on macOS: https://blog.kulman.sk/implementing-auto-type-on-macos/
- Adonis Gaitatzis — Capture Key Bindings in Swift: https://gaitatzis.medium.com/capture-key-bindings-in-swift-3050b0ccbf42

---
*Architecture research for: macOS chord-based typing menubar app (ChordTyper)*
*Researched: 2026-05-18*
