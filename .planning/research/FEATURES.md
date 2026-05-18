# Feature Research

**Domain:** macOS chord-based typing / keyboard macro utility
**Researched:** 2026-05-18
**Confidence:** HIGH (core features), MEDIUM (UX patterns), LOW (edge case detection)

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist in any keyboard-intercepting utility. Missing these = product feels broken or untrustworthy.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Chord detection on simultaneous keypress | The core premise; without this the app does not exist | HIGH | CGEventTap at session level; evaluate on all-keys-released to avoid false positives during chord formation |
| Key-order-independent matching | Users cannot reliably press keys in a fixed order simultaneously; T+H+E and H+E+T must be identical | MEDIUM | Sorted-alphabetical encoding as dictionary key; O(1) lookup |
| Configurable timing window | Different keyboards, USB vs BT, different users all have different rollover timing; one fixed value causes false positives for fast typists or misses for slow | MEDIUM | 20–200ms range; 50ms default; slider in settings |
| Unmatched chord pass-through | Any unrecognised combination must replay all keys normally — user cannot lose keystrokes | HIGH | Reconstruct and replay collected keys in original timestamp order; this is what differentiates from text expansion |
| Global toggle (on/off) | Users must be able to disable immediately when app misbehaves or they enter a context where chords are unwanted | LOW | Menubar click + global shortcut (Cmd+Shift+Space) |
| Menubar icon with active/inactive state | System-level utilities live in the menubar; no Dock icon expected; visual state at a glance is required | LOW | SF Symbol or custom; muted/strikethrough when paused |
| Accessibility permission detection + guidance | macOS requires explicit user consent before an app can intercept keystrokes; app must detect absence and guide the user | MEDIUM | Check AXIsProcessTrusted(); show prompt to System Settings > Privacy & Security > Accessibility |
| Secure input detection (password field passthrough) | Any keyboard intercept tool that fires in password fields is a security liability and a trust killer | MEDIUM | macOS raises SecureEventInput; CGEventTap receives no events in this state — handle gracefully rather than actively detect |
| Per-app blacklist/whitelist | Users will encounter apps (IDEs, games, terminals) where chords collide with existing shortcuts; they must be able to exclude those apps | MEDIUM | Check frontmostApplication.bundleIdentifier on each chord evaluation; store in UserDefaults |
| Quit from menubar | Standard convention; no menubar utility omits this | LOW | Single menu item |

### Differentiators (Competitive Advantage)

Features that go beyond baseline. These align with ChordTyper's specific core value: reliable chord detection for prose writing across languages, on standard Mac hardware with no proprietary dependencies.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| IME-transparent keystroke interception | CGEventTap at driver level sees raw key codes regardless of active input method. Thai IME, Japanese IME, etc. do NOT interfere. Plover and ZipChord both fail here on macOS because they rely on higher-level event APIs | HIGH | This is the key architectural differentiator vs. alternatives. Must use kCGSessionEventTap + kCGHeadInsertEventTap |
| Thai-language chord dictionary | No existing chord typing app targets Thai. Covers ~100 most common words using QWERTY key codes mapped to Thai Unicode output | HIGH | Requires NECTEC/Lexitron frequency corpus analysis; key codes are QWERTY raw codes regardless of which IME is active |
| Smart space management | Auto-append space after chord word; remove space before punctuation. Removes friction from mixing chord and regular typing. ZipChord has this; macOS system text replacement does not | MEDIUM | Track "last output was a chord" state; on next keyup check if it is punctuation character |
| Hot-reload dictionaries | Edit JSON, changes take effect immediately without restarting the app. Lowers the iteration cost of building a personal dictionary | MEDIUM | DispatchSource.makeFileSystemObjectSource watching dictionary directory |
| Zero third-party dependencies | Audit, build, and distribute without supply chain risk; no Homebrew bottles or CocoaPods locked to a vendor's release schedule | HIGH (design constraint, not a feature to add) | Pure Apple frameworks; impacts every phase |
| ZipChord-compatible English chord assignments | Users who already learned ZipChord chords on Windows can switch to Mac without re-learning muscle memory | LOW | Source English dictionary from ZipChord MIT-licensed corpus; document compatibility explicitly |
| CLI-buildable / xcodegen | Developer can build, test, and package from terminal without opening Xcode GUI. Enables reproducible builds and scripting | MEDIUM | xcodegen + Makefile targets: build, run, dmg, clean |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem like obvious additions but create problems for this specific project.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| In-app chord editor / dictionary UI | Users want a GUI to add/edit chords without touching JSON | A full CRUD editor is 3-5x the UI complexity of settings; it diverges focus from detection reliability; JSON is already simple and the target user is technical | Ship with well-commented JSON + "Open Dictionary Folder" shortcut; hot-reload makes editing fast |
| Chord hints overlay / visualizer | ZipChord shows available chords in a floating tooltip; CharaChorder shows chord suggestions | A floating overlay requires a separate window, z-order management, per-app positioning logic, and adds latency to every keypress. For prose writing the benefit is low once chords are learned | Include a printed chord reference sheet in the DMG; consider a static "cheat sheet" Settings tab if users request it after launch |
| Typing statistics / WPM counter | Users like seeing productivity metrics | Metrics require persistent storage, a display surface, and create maintenance burden. They do not improve chord reliability — the core value | Defer entirely; if validated post-launch, add as a read-only settings tab reading from UserDefaults counters |
| Cloud sync of dictionaries | Users with multiple Macs want dictionaries in sync | iCloud sync introduces CloudKit entitlements, conflict resolution, and Apple Developer account dependency; personal-use app has one user on one primary Mac | Dictionaries are plain JSON files; user can manually copy or put them in a synced folder (iCloud Drive, Dropbox) |
| Apple notarization / App Store distribution | Wider distribution | Requires paid Apple Developer account; scope is personal use; ad-hoc signing is sufficient for Gatekeeper on personal machines | Ad-hoc signing (`CODE_SIGN_IDENTITY="-"`); document manual Gatekeeper bypass for first launch |
| Shorthands (sequential abbreviation expansion) | ZipChord supports shorthands alongside chords; users request text expansion on top of chord typing | Shorthands need a separate state machine tracking typed character sequences; this is a different input model from simultaneous chords and significantly complicates the event tap logic | Stay chord-only; macOS system text replacement handles sequential shorthands natively |
| iOS / iPadOS port | Mobile typing is also slow | CGEventTap does not exist on iOS; would require entirely different architecture; separate project | Explicitly out of scope; document why |
| Multiple chord dictionaries per language slot | Power users want to stack community dictionaries | Priority conflict resolution, ordering UI, and edge case handling multiply; for a single user this is over-engineering | One JSON file per language; user merges manually |

---

## Feature Dependencies

```
[Accessibility Permission Detection]
    └──required-by──> [CGEventTap Activation]
                          └──required-by──> [Chord Detection]
                                                └──required-by──> [Key Suppression]
                                                └──required-by──> [Unmatched Pass-through]

[Chord Detection]
    └──required-by──> [Text Output]
                          └──enhanced-by──> [Smart Space]

[Dictionary Manager]
    └──required-by──> [Chord Detection]
    └──enhanced-by──> [Hot-reload]

[Per-app Filter]
    └──required-by──> [Chord Detection] (guard evaluated before lookup)

[Secure Input Detection]
    └──required-by──> [Chord Detection] (passthrough guard)

[Global Toggle]
    └──required-by──> [CGEventTap] (enable/disable tap)
    └──required-by──> [Menubar Icon] (state display)

[Menubar Icon]
    └──required-by──> [Settings Window] (entry point)

[Settings Window]
    └──contains──> [Timing Slider]
    └──contains──> [Dictionary Toggles]
    └──contains──> [Per-app Filter List]
```

### Dependency Notes

- **Accessibility Permission Detection required before CGEventTap:** The event tap will silently fail or crash if Accessibility permission is missing. Detection and guidance must be Phase 3, not Phase 10.
- **Chord Detection requires Dictionary Manager:** Cannot evaluate chords without a loaded dictionary; dictionary loading must precede detection logic.
- **Per-app Filter is a guard, not a post-processor:** It must be checked before the chord lookup on every keypress, not after. Wrong ordering causes phantom output.
- **Secure Input is handled by macOS automatically:** When SecureEventInput is active, CGEventTap simply stops receiving events from that app. The app does not need to detect this actively — it needs to handle the resulting event gap gracefully (e.g., flush partial chord state when events stop arriving).
- **Smart Space enhances Text Output but does not block it:** Smart Space can be disabled without breaking chord output; it is layered on top.

---

## MVP Definition

### Launch With (v1)

Minimum viable product — validates the core premise that chord typing is faster for prose.

- [x] CGEventTap with Accessibility permission detection and guidance
- [x] Chord detection: timing window (50ms default, 20-200ms configurable), key-order-independent, evaluate on release
- [x] Unmatched chord pass-through (replay all keys)
- [x] JSON dictionary loading (English ~150 words, Thai ~100 words)
- [x] Hot-reload on dictionary file change
- [x] Text output: key suppression + word output
- [x] Smart space: auto-append, remove before punctuation
- [x] Per-app blacklist/whitelist by bundle ID
- [x] Secure input passthrough (graceful handling of event gap)
- [x] Menubar icon with active/paused state and dropdown menu
- [x] Global toggle shortcut (Cmd+Shift+Space)
- [x] Settings window: timing slider, dictionary toggles, app filter, shortcut display
- [x] Ad-hoc signed DMG via `make dmg`

### Add After Validation (v1.x)

Add once the core chord loop is proven reliable in daily use.

- [ ] Launch at login — add once the app is stable enough for daily background use; avoid shipping broken auto-start
- [ ] Chord reference cheat sheet in Settings — trigger: users ask "what are my chords?" more than 3 times
- [ ] Typing statistics (simple counter in UserDefaults) — trigger: user explicitly requests; display-only, no cloud

### Future Consideration (v2+)

Defer until product-market fit is established or user base grows beyond single developer.

- [ ] Plugin/extension system for additional languages — requires stable API surface
- [ ] Community dictionary format / import from ZipChord .zip files — requires format spec documentation
- [ ] Chord hints overlay — requires validation that it does not hurt flow state more than it helps

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| CGEventTap chord detection | HIGH | HIGH | P1 |
| Unmatched pass-through | HIGH | HIGH | P1 |
| Accessibility permission detection | HIGH | MEDIUM | P1 |
| JSON dictionary loading | HIGH | LOW | P1 |
| Text output + key suppression | HIGH | MEDIUM | P1 |
| Smart space | HIGH | MEDIUM | P1 |
| Menubar icon + toggle | HIGH | LOW | P1 |
| Global shortcut toggle | HIGH | LOW | P1 |
| Per-app filter | MEDIUM | MEDIUM | P1 |
| Secure input passthrough | HIGH | LOW | P1 |
| Settings window | MEDIUM | MEDIUM | P1 |
| Hot-reload dictionaries | MEDIUM | LOW | P1 |
| Thai dictionary | HIGH (for target user) | MEDIUM | P1 |
| Launch at login | MEDIUM | LOW | P2 |
| Chord hints overlay | LOW | HIGH | P3 |
| In-app dictionary editor | MEDIUM | HIGH | P3 |
| Typing statistics | LOW | MEDIUM | P3 |
| Cloud sync | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for v1 — without these the app cannot be used or is untrustworthy
- P2: Should have; add in v1.x patch once core is validated
- P3: Nice to have; future consideration only

---

## Competitor Feature Analysis

| Feature | ZipChord (Windows) | Plover (steno, cross-platform) | Karabiner-Elements (macOS) | macOS Text Replacement | ChordTyper Approach |
|---------|-------------------|-------------------------------|---------------------------|----------------------|---------------------|
| Chord detection model | Simultaneous keys, release-based | Steno chords (chord-per-stroke) | Simultaneous key rules ("from" + "to") | Sequential abbreviation, space-triggered | Simultaneous, release-based, 3-key minimum |
| Dictionary format | CSV files | JSON + RTF/CRE (plugin-extensible) | JSON complex rules | System Preferences UI (plist) | UTF-8 JSON with sorted-alphabetical key encoding |
| Hot-reload | Unknown / requires restart | Requires reload command | Requires restart | Requires System Prefs save | DispatchSource file watch; immediate |
| Thai / non-Latin language | No | Via steno theory plugin | Remapping only, not word output | iCloud-synced, limited | Native via key-code-to-Unicode mapping independent of IME |
| Smart space | Yes (contextual) | Yes (steno convention) | No | No (space-triggered replacement) | Yes: append after chord, strip before punctuation |
| Per-app filtering | Profiles with auto-switching | No | Yes (device + app conditions) | Not possible | Blacklist/whitelist by bundle ID |
| Secure input | Blocked by OS automatically | Blocked by OS automatically | Blocked by OS automatically | Blocked by OS automatically | Graceful state flush when events stop |
| Chord hints / visualizer | Yes (on-screen display + tooltips) | No | No | No | Explicitly out of scope for v1 |
| Plugin system | No | Yes (Python plugins) | No (JSON-only rules) | No | No; zero dependencies |
| macOS native | No (AutoHotKey) | Yes (Python app) | Yes (kernel extension / virtual HID) | Yes (system feature) | Yes (Swift + CGEventTap) |
| IME-transparent | No | No | Partial (key code level) | No | Yes (CGEventTap below IME layer) |

---

## Sources

- [ZipChord GitHub repository](https://github.com/psoukie/zipchord) — features list, README, Wiki
- [ZipChord: Hybrid Chorded Keyboard](https://pavelsoukenik.com/zipchord-hybrid-chorded-keyboard) — author's overview
- [ZipChord Hacker News discussion](https://news.ycombinator.com/item?id=34633419) — community usage patterns and pain points
- [CharaChorder Docs — Chords](https://docs.charachorder.com/Chords.html) — chord model, impulse chording
- [CharaChorder Wikipedia](https://en.m.wikipedia.org/wiki/CharaChorder) — hardware design rationale
- [Plover open source steno engine](https://opensteno.org/plover/) — feature set, plugin system
- [Plover GitHub](https://github.com/opensteno/plover) — plugin architecture, dictionary format
- [Plover Docs 5.3.0](https://plover.readthedocs.io/) — machine protocols, steno system design
- [Karabiner-Elements features](https://karabiner-elements.pqrs.org/docs/getting-started/features/) — complex modifications, per-app rules, profiles
- [TextExpander and Secure Input](https://textexpander.com/secure-input) — secure input behavior, what it blocks and why
- [Keyboard Maestro Secure Input](https://wiki.keyboardmaestro.com/assistance/Secure_Input_Problem) — failure modes when secure input is not released correctly
- [Apple Developer — The menu bar HIG](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar) — menubar icon conventions, template images
- [macOS Text Replacement](https://support.apple.com/guide/mac-help/replace-text-punctuation-documents-mac-mh35735/mac) — limitation: sequential only, not system-wide in all apps
- [N-Key Rollover and fast typing](https://typetest.io/blog/posts/2026-03-12-keyboard-n-key-rollover-for-fast-typing.html) — why timing windows and rollover handling matter

---

*Feature research for: macOS chord-based typing app (ChordTyper)*
*Researched: 2026-05-18*
