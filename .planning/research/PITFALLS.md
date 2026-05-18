# Pitfalls Research

**Domain:** macOS keyboard interception / chord-based typing app (Swift + CGEventTap)
**Researched:** 2026-05-18
**Confidence:** HIGH — multiple independent sources, cross-verified with real production failures (Ghostty, Wispr Flow, Keyboard Maestro, TextExpander)

---

## Critical Pitfalls

### Pitfall 1: TCC Identity Invalidation After Re-signing (The Silent Disable Race)

**What goes wrong:**
The event tap installs successfully (`CGEventTapCreate` returns non-nil), callbacks never fire, and there is no error message. The tap is functionally inert. This happens after rebuilding the app — even with ad-hoc signing — because macOS's TCC (Transparency, Consent, and Control) system ties Input Monitoring and Accessibility permissions to code identity (the signing hash). Each rebuild with a different identity is treated as a new, unpermissioned app by Launch Services.

**Why it happens:**
Launching via Finder, Dock, or `open` (Launch Services) triggers strict code-identity verification. The TCC database entry for the old identity does not carry over. Launching the raw binary directly bypasses this check, which is why "it works in Terminal but not from the Dock."

**How to avoid:**
- Add a runtime health check: install a repeating 5-second `DispatchSourceTimer` that calls `CGEvent.tapIsEnabled()` and reinstalls the tap if false.
- Call `CGPreflightListenEventAccess()` before `CGEventTapCreate` and surface a UI error when false.
- After tap creation, delay 1 second then verify `tapIsEnabled` — mitigation for the TCC re-evaluation race on first launch.
- In the Makefile `run` target, always revoke and re-grant TCC on the build product before launching (`tccutil reset Accessibility com.yourapp.bundleid` during development).
- Never treat a non-nil `CGEventTapCreate` return as proof the tap is healthy.

**Warning signs:**
- Tap installs silently but keystrokes are not intercepted after rebuilding.
- Works from `./Build/ChordTyper` directly but not from `.app` bundle via Finder.
- `CGEvent.tapIsEnabled()` returns false immediately after install.

**Phase to address:** Event tap scaffold phase (the very first phase that installs the tap). Health monitoring must be wired in before any feature work builds on top.

---

### Pitfall 2: Tap Silently Disabled After Sleep/Wake or Screen Lock

**What goes wrong:**
The chord interceptor works after launch but stops functioning after the Mac sleeps, wakes, locks, or the user switches accounts. macOS disables the tap with `kCGEventTapDisabledByTimeout` or `kCGEventTapDisabledByUserInput`, neither of which crashes the app — the tap simply stops delivering events. Documented in Ghostty (discussion #11819) as a real production regression.

**Why it happens:**
Three failure modes compound:
1. The tap-disabled callback path is not handled — `kCGEventTapDisabledByTimeout` arrives in the callback but is ignored.
2. No `NSWorkspaceDidWakeNotification` handler reinstalls the tap after wake.
3. Session-switch events invalidate the tap's mach port without notification.

**How to avoid:**
- In the event tap callback, check for `type == .tapDisabledByTimeout` or `type == .tapDisabledByUserInput` and call `CGEventTapEnable(tap, true)` immediately.
- Register for `NSWorkspace.didWakeNotification` and reinstall the full tap (create new, add to run loop) on wake.
- The 5-second health-check timer (Pitfall 1) doubles as recovery here — it catches any disabling not caught by the callback.

**Warning signs:**
- Chord detection works after boot, stops working after lid close/open.
- Menubar icon still shows "active" but no chords fire.
- No crash, no log output.

**Phase to address:** Event tap scaffold phase — the tap lifecycle management (create/enable/disable/recreate) must be a first-class design concern, not an afterthought.

---

### Pitfall 3: Stale Key-Down State Causing Phantom Chords or Suppressed Normal Keys

**What goes wrong:**
The chord detector tracks which keys are currently held (`keysDown: Set<CGKeyCode>`). If a key-up event is lost or arrives out of order, a key remains permanently "stuck" in the set. Every subsequent keypress then matches a chord-like pattern and gets suppressed. This is the exact failure mode documented in the Wispr Flow forensic investigation — 145 consecutive spacebar presses were eaten because Right Option was stuck in the tracking set.

**Why it happens:**
Key-up events can be lost if:
- The chord detection processes events asynchronously via GCD and a queue stalls.
- The app is not frontmost when a modifier key is released.
- Secure Input engagement causes the tap to miss key-up events.
- The app is launched (or rebuilt) while keys are held.

**How to avoid:**
- Process all key events synchronously inside the tap callback (no async dispatch for state mutation). Dispatch only the output step (the `CGEventPost` of the chord word) to the main queue.
- On chord evaluation (all-keys-released trigger), clear `keysDown` unconditionally before evaluating — do not trust accumulated state.
- Add a "stale key" safety valve: if any key has been in `keysDown` for more than 2 seconds without a corresponding key-up, evict it and log a warning.
- On app activate/focus-gain, reset `keysDown` to empty.

**Warning signs:**
- Normal single-keystrokes are being suppressed intermittently.
- Chord fires for a combination that was never pressed together.
- After using a modifier key (Cmd, Option, Shift), normal typing breaks.

**Phase to address:** Chord detection logic phase — the state machine must be designed with explicit eviction, not just insertion/removal.

---

### Pitfall 4: Unicode Output Unreliable via CGEventKeyboardSetUnicodeString

**What goes wrong:**
For Thai character output, using `CGEventKeyboardSetUnicodeString` on a synthesized `CGEvent` appears to work in some apps but is silently ignored in others (particularly Electron apps, terminal emulators, and apps that remap keyboard input). The receiving app ignores the Unicode string payload and performs its own keyCode→character translation, outputting the wrong character or nothing.

**Why it happens:**
Application frameworks are not required to use the Unicode string embedded in a keyboard event — they can (and many do) re-derive the character from the virtual keycode plus modifier state based on the active keyboard layout. This behavior reportedly worsened on macOS 12+. Thai characters have no direct virtual keycode mapping on a QWERTY layout, so keyCode-based derivation produces garbage.

**How to avoid:**
- Use `NSPasteboard` + `Cmd+V` paste injection as the primary output strategy for Thai Unicode characters. This bypasses the keyboard pipeline entirely and is universally reliable.
- For English output, virtual keycodes with correct keyCode values are reliable — use keyCode-based events only for Latin characters.
- Test output in: Safari, Chrome (Electron-based apps), Terminal, VS Code (Electron) — these represent the failure-prone spectrum.
- Do not rely on `CGEventKeyboardSetUnicodeString` as the sole output method for non-ASCII characters.

**Warning signs:**
- Thai characters output correctly in TextEdit but wrong in VS Code or iTerm2.
- Output is a Latin character where a Thai character was expected.
- Different behavior depending on which keyboard layout is active in System Settings.

**Phase to address:** Chord output phase — design dual output strategies (keyCode for ASCII, pasteboard for Unicode) from the start, not as a retrofit.

---

### Pitfall 5: Tap Callback Blocking the Event Pipeline (Latency / Timeout Cascade)

**What goes wrong:**
The CGEventTap callback runs synchronously on the thread where the run loop is pumping. Any blocking operation inside the callback (I/O, synchronous dispatch to another queue, slow dictionary lookup) stalls the entire event pipeline. If the callback takes too long, macOS auto-disables the tap (`kCGEventTapDisabledByTimeout`). Even without auto-disable, input latency becomes perceptible and the system becomes sluggish.

**Why it happens:**
Developers unfamiliar with run-loop-pinned callbacks dispatch heavy work (logging, file I/O for hot-reload, notification posting) synchronously inside the callback, assuming it runs on a "background" thread.

**How to avoid:**
- Keep the tap callback under 1ms. The callback should only: update `keysDown` state, decide suppress/passthrough, and optionally enqueue a post-chord output task.
- Use `DispatchQueue.main.async` only for UI updates from callback results — never for state mutation.
- Pre-load the chord dictionary into memory at startup; never read from disk inside the callback. Hot-reload via `DispatchSource` should write to an atomically-swapped reference, not reload in the callback path.
- Avoid `os_log` calls inside the tap callback in production builds — they involve syscalls.

**Warning signs:**
- `kCGEventTapDisabledByTimeout` messages appear in Console.app.
- System-wide input latency increases when ChordTyper is running.
- Other apps' keyboard shortcuts fire slowly.

**Phase to address:** Event tap scaffold phase and chord detection logic phase — establish the callback discipline early; it is very hard to retrofit.

---

### Pitfall 6: Secure Keyboard Entry Disables the Tap — But Can Get Stuck

**What goes wrong:**
macOS Secure Keyboard Entry (SKE) prevents any event tap from receiving key events when a secure text field has focus (e.g., password fields, Terminal with SKE enabled, 1Password, banking sites). This is expected and correct behavior. The pitfall is twofold: (1) failing to detect SKE and leaving the menubar in "active" state confuses users, and (2) some apps (KeePassXC, Terminal) can leave SKE enabled after losing focus, blocking ChordTyper in all subsequent apps until the user restarts the offending app.

**Why it happens:**
SKE is a system-wide semaphore. Any app can enable it and forget to release it on deactivation. This is a bug in the offending app, but ChordTyper appears broken to the user.

**How to avoid:**
- Detect SKE state using the private-but-stable `IsSecureEventInputEnabled()` C function from `<Carbon/Carbon.h>` (used by Keyboard Maestro, TextExpander, BetterTouchTool).
- Poll SKE state every 1 second using the same health-check timer and update the menubar icon to a "paused (secure input)" visual state.
- Show a user-facing message: "Chord typing paused — another app has enabled Secure Keyboard Input. Restart [offending app] to restore."
- Do not expose this as a bug — surface it as a known system behavior with clear user guidance.

**Warning signs:**
- ChordTyper stops working after using a password manager or Terminal.
- Tap returns `kCGEventTapDisabledByUserInput` repeatedly.
- Issue persists across different apps until a specific app is quit.

**Phase to address:** Permissions and state management phase (after tap scaffold). SKE detection belongs in the health-check loop alongside tap-enabled verification.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Global Swift function for tap callback (not a method) | Compiles and works immediately | Requires `UnsafeMutableRawPointer` to pass `self`; unsafe if lifetime is not managed | Always required — C callbacks cannot capture Swift context; use the `userInfo` pointer pattern from day one |
| Synchronous dictionary lookup in callback | Simple code | Blocks event pipeline; causes timeout disable under load | Never — pre-load dictionary into an in-memory `Set<String>` |
| Checking `CGEventTapCreate != nil` as permission proof | Avoids extra code | Misses TCC silent-disable; tap exists but is inert | Never — always check `tapIsEnabled` after a delay |
| Single flat `keysDown` Set without eviction | Works for happy path | Stuck-key bugs that are nearly impossible to reproduce deterministically | MVP only if keyboard is never released mid-session |
| Hardcoded `Cmd+Shift+Space` toggle shortcut | Quick to implement | Conflicts with Spotlight language toggle, various IDE shortcuts | Acceptable in MVP if the shortcut is user-configurable in Settings |
| NSPasteboard output for all characters (not just Thai) | Simpler code | Overwrites user clipboard; breaks copy-paste workflow | Never — use pasteboard only for Thai Unicode, keyCode for ASCII |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| CGEventTap + TCC permissions | Checking `AXIsProcessTrusted()` and assuming that covers CGEventTap Input Monitoring | `AXIsProcessTrusted()` checks Accessibility; CGEventTap active taps need Input Monitoring (`CGPreflightListenEventAccess()`). They are separate TCC entries. |
| NSWorkspace `frontmostApplication` in tap callback | Calling `NSWorkspace.shared.frontmostApplication` synchronously inside the tap callback | Cache the frontmost bundle ID via `NSWorkspace.didActivateApplicationNotification`; the tap callback must only read the cached value, never call into AppKit |
| DispatchSource hot-reload + tap callback | Reading updated dictionary reference while tap callback reads the same reference | Use `os_unfair_lock` or a read-write lock; or swap an `AtomicReference` (class wrapper around a dictionary) atomically |
| CGEventPost + active tap | Synthetic events re-enter the tap, causing the chord output to be re-processed and suppressed | Mark synthetic events with a custom flag (`CGEventSetIntegerValueField(.eventSourceUserData, value: 0xCH0RD)`) and skip them in the callback |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| JSON dictionary parse on every chord evaluation | Imperceptible at first, O(N) grows with dictionary size | Parse once at load; store as `[String: String]` dictionary in memory | With 1000+ chord entries, parsing overhead becomes measurable |
| O(N) chord matching (iterate all keys) | Latency grows with dictionary size | Pre-sort keys alphabetically; use `Dictionary` with O(1) lookup using the sorted-key string as the dictionary key | Already avoided by the sorted-alphabetical key encoding design |
| Dispatch to main queue for every key event | Fine at normal typing speed; degrades under burst input | Use a dedicated serial queue for chord state; dispatch only output to main | Under fast typing bursts (>10 keys/sec) the main queue backlog causes noticeable lag |
| Allocating new `Set<CGKeyCode>` per event | Imperceptible on Apple Silicon; battery drain over hours | Mutate a single persistent `Set` in the callback; avoid allocation in the hot path | Always-on apps accumulate allocations; this matters for battery on MacBook |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Logging raw keystrokes to a file for debugging | Full keylogger; captures passwords, credit cards, secrets | Never log key event payloads; log only chord match results (word → output) with the keycodes stripped |
| Leaving the tap active when Secure Input is detected | Potential side-channel (even if events are not delivered, the tap state can be observed) | Disable the tap or skip processing entirely when `IsSecureEventInputEnabled()` returns true |
| Using `kCGAnnotatedSessionEventTap` without checking entitlements | Silently fails; also captures events from other user sessions on Fast User Switching systems | Use `kCGHIDEventTap` for system-wide interception; verify the level with a test event at startup |
| Not clearing `keysDown` when app loses focus | Modifier keys from the previous context leak into the chord detector | Clear on `NSWorkspace.didDeactivateApplicationNotification` for the monitored apps |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No visual feedback when tap is disabled (sleep/SKE/timeout) | User thinks the app is broken and files a bug or uninstalls | Menubar icon changes: filled (active), dimmed (paused by user), orange-dot (disabled by system/SKE) |
| Smart space appended before punctuation is not removed | Output: "word ." instead of "word." | Detect next keypress after chord output; if it is a punctuation character, delete the trailing space before inserting it |
| Chord fires during fast sequential typing ("th" typed fast triggers "the") | Frustrating false positives destroying flow | Timing window must be measured from the first key-down of the potential chord, not from last key-down. Keys pressed more than the window apart must be flushed as individual characters |
| No way to temporarily disable per-app without opening settings | Interrupts writing flow | Menubar dropdown → "Pause for [App Name]" adds current app to blacklist immediately |
| Chord output during app startup (before dictionaries are loaded) | Random output or crash | Defer tap installation until dictionary is confirmed loaded; show a loading state in menubar |

---

## "Looks Done But Isn't" Checklist

- [ ] **Event tap health:** Tap installs and callback fires — verify `tapIsEnabled` is still true 5 seconds after launch AND after sleep/wake.
- [ ] **Synthetic event loop:** Chord output via `CGEventPost` re-enters the tap — verify output events are marked and skipped in callback.
- [ ] **Thai Unicode output:** Thai words output correctly in Safari, Chrome, VS Code, and iTerm2 — not just TextEdit.
- [ ] **Secure Input detection:** ChordTyper's menubar shows "paused" state when Terminal has Secure Keyboard Entry enabled.
- [ ] **Stuck-key recovery:** Hold Cmd, switch to another app, return — verify no phantom Cmd modifier in subsequent chord detection.
- [ ] **Sleep/wake recovery:** Sleep Mac for 30 seconds, wake, verify chord detection resumes without restarting the app.
- [ ] **Rebuild cycle:** Build, grant permission, rebuild — verify tap still fires without needing to re-grant permission (or surfaces a clear re-grant prompt).
- [ ] **Fast typing pass-through:** Type "the" quickly as individual letters — verify it does NOT trigger a "the" chord and the letters appear individually.
- [ ] **Smart space punctuation:** Type a chord followed immediately by "." — verify no space appears between the word and the period.
- [ ] **App blacklist:** Add Terminal to blacklist — verify chords do not fire in Terminal but fire in TextEdit.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| TCC identity invalidation after rebuild | LOW | Quit app, revoke TCC via `tccutil reset All <bundleid>`, relaunch, re-grant permission |
| Stuck event tap after sleep | LOW | Tap health-check timer auto-recovers within 5 seconds; if not, menubar "Restart Tap" action |
| Stuck key in `keysDown` | LOW | Stale-key eviction timer clears after 2 seconds; worst case, toggle off/on via Cmd+Shift+Space |
| Thai Unicode output broken in target app | MEDIUM | Switch to pasteboard injection strategy for Thai; requires output-mode abstraction if not built in from start |
| Callback timeout causing tap auto-disable | MEDIUM | Profile callback hotpath; refactor any blocking I/O or synchronous dispatch; rebuild with instrumentation |
| NSPasteboard clipboard clobber | HIGH | Requires redesigning Thai output: capture clipboard → paste → restore clipboard asynchronously; 3-step process with timing risks |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| TCC silent disable after rebuild | Phase 1 (event tap scaffold) | Rebuild twice, launch from Finder, verify tap fires |
| Sleep/wake tap disabling | Phase 1 (event tap scaffold) | Sleep/wake cycle test in CI or manual checklist |
| Stale key-down state | Phase 2 (chord detection logic) | Unit test: inject key-down without key-up, verify eviction |
| Thai Unicode via `CGEventKeyboardSetUnicodeString` | Phase 3 (chord output) | Test in VS Code and iTerm2, not just TextEdit |
| Callback blocking / timeout cascade | Phase 1–2 (scaffold + detection) | Add `os_signpost` timing; fail if callback exceeds 0.5ms |
| Secure Keyboard Entry blind spot | Phase 4 (permissions + UI) | Enable SKE in Terminal, verify menubar reflects state |
| Synthetic event re-entry loop | Phase 3 (chord output) | Inject chord output, verify no second chord fires |
| Smart space before punctuation | Phase 3 (chord output) | Integration test: chord + "," produces "word," not "word ," |
| Chord false positive during fast typing | Phase 2 (chord detection) | Type 60wpm sample text, verify zero false chord fires |
| App blacklist bundle ID detection | Phase 5 (settings/filtering) | Verify NSWorkspace notification fires on app switch, not polling |

---

## Sources

- [CGEvent Taps and Code Signing: The Silent Disable Race — Daniel Raffel (2026-02-19)](https://danielraffel.me/til/2026/02/19/cgevent-taps-and-code-signing-the-silent-disable-race/)
- [macOS: Global keybinds stop working after sleep/wake — CGEventTap not re-enabled (Ghostty discussion #11819)](https://github.com/ghostty-org/ghostty/discussions/11819)
- [How Wispr Flow Ate My Spacebar: A Forensic Investigation Into Silent Keyboard Interception — Wensen Wu](https://www.wensenwu.com/thoughts/wispr-flow-investigation)
- [Secure Input Problem — Keyboard Maestro Wiki](https://wiki.keyboardmaestro.com/assistance/Secure_Input_Problem)
- [CGEventPost with Emoji unicode — Apple Developer Forums](https://developer.apple.com/forums/thread/706245)
- [keyboardSetUnicodeString Apple Developer Documentation](https://developer.apple.com/documentation/coregraphics/cgevent/1456028-keyboardsetunicodestring)
- [tapCreate Apple Developer Documentation](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:))
- [FB12113281: event taps stop receiving events — feedback-assistant/reports #390](https://github.com/feedback-assistant/reports/issues/390)
- [CGEventTapCreate fail on Mojave — Apple Developer Forums](https://developer.apple.com/forums/thread/109283)
- [Accessibility Permission in macOS — jano.dev (2025-01-08)](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html)
- [EventTapper — usagimaru/EventTapper (reference Swift implementation)](https://github.com/usagimaru/EventTapper)
- [ZipChord infinite loop bug — psoukie/zipchord issue #200](https://github.com/psoukie/zipchord/issues/200)

---
*Pitfalls research for: macOS chord-based typing app (CGEventTap / Swift)*
*Researched: 2026-05-18*
