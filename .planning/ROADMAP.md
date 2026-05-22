# Roadmap: ChordTyper

## Overview

ChordTyper is built bottom-up in 10 phases: scaffold → menubar skeleton → event tap → chord detection → dictionary → text output → global toggle → settings → app filter → polish and packaging. Each phase delivers a single coherent capability and is verifiable by running `make build && make test`. No phase is complete without passing XCTest unit tests.

## Phases

**Phase Numbering:**

- Integer phases (1--10): Planned milestone work
- Decimal phases (e.g. 2.1): Urgent insertions (marked INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Project Scaffold** - project.yml, Makefile, folder structure, Info.plist, entitlements
- [x] **Phase 2: Menubar Skeleton** - AppDelegate, menubar icon, menu items, quit (completed 2026-05-18)
- [x] **Phase 3: CGEventTap** - setup, permissions check, keydown/keyup capture, pass-through (completed 2026-05-22)
- [ ] **Phase 4: Chord Detection** - timing window, key collection, sorted-key lookup
- [ ] **Phase 5: Dictionary System** - JSON loading, hot-reload, English + Thai dict files
- [ ] **Phase 6: Text Output** - key suppression, word output, smart space logic
- [ ] **Phase 7: Global Toggle** - menubar click + Cmd+Shift+Space shortcut
- [ ] **Phase 8: Settings Window** - timing slider, dictionary toggles, app filter list
- [ ] **Phase 9: App Blacklist/Whitelist** - per-app filtering, bundle ID detection
- [ ] **Phase 10: Polish + Packaging** - permissions UX, make dmg, security

## Phase Details

### Phase 1: Project Scaffold

**Goal**: A CLI-buildable project skeleton exists with correct structure, entitlements, and build targets
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: SCAF-01, SCAF-02, SCAF-03, SCAF-04, SCAF-05
**Success Criteria** (what must be TRUE):

  1. `xcodegen generate` produces a valid .xcodeproj with no errors
  2. `make build` compiles and links the app successfully
  3. `make test` runs the XCTest suite and all tests pass (skeleton test target exists)
  4. The built app has LSUIElement=YES so it does not appear in the Dock
  5. Entitlements file declares com.apple.security.temporary-exception.accessibility permission

**Plans:** 1 plan
Plans:

- [x] 01-01-PLAN.md -- Project scaffold: all files, build/test verification, menubar launch check

### Phase 2: Menubar Skeleton

**Goal**: The app launches as a menubar-only app with an icon, a working dropdown menu, and a quit action
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: MENU-01, MENU-02, MENU-03, MENU-04
**Success Criteria** (what must be TRUE):

  1. App launches with no Dock icon and appears only in the menu bar
  2. Menubar icon uses the SF Symbol keyboard graphic with distinct active/paused visual states
  3. Clicking the icon shows a dropdown with toggle, dictionary items, Settings, Open Dictionary Folder, and Quit
  4. Clicking Quit terminates the app cleanly
  5. `make build && make test` passes (menu state unit tests)

**Plans:** 2 plans (1 complete, 1 gap closure)
Plans:

- [x] 02-01-PLAN.md -- Menubar skeleton: full menu structure, icon states, toggles, unit tests, visual verification
- [x] 02-02-PLAN.md -- Gap closure: add placeholder dictionaries and guard Open Dictionary Folder action

**UI hint**: yes

### Phase 3: CGEventTap

**Goal**: The app captures all keydown and keyup events at driver level, checks for Accessibility permission, and passes all events through unchanged
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: EVNT-01, EVNT-02, EVNT-03, EVNT-04, EVNT-05
**Success Criteria** (what must be TRUE):

  1. Keystrokes appear in any frontmost app unchanged (tap is transparent at this phase)
  2. If Accessibility permission is missing, the app shows clear guidance to System Settings
  3. The tap re-enables itself automatically when disabled by timeout (kCGEventTapDisabledByTimeout)
  4. The tap recovers after the Mac sleeps and wakes (NSWorkspace notification)
  5. `make build && make test` passes (EventTapManager unit tests for re-enable logic)

**Plans:** 2 plans (complete)
Plans:
**Wave 1**

- [x] 03-01-PLAN.md -- EventTapManager + AppDelegate + adaptor wiring + unit tests + Makefile tccutil

**Wave 2**

- [x] 03-02-PLAN.md -- Human verification: transparent pass-through and permission UX

### Phase 4: Chord Detection

**Goal**: The ChordEngine correctly detects simultaneous key presses within a configurable timing window and performs order-independent lookup
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: CHRD-01, CHRD-02, CHRD-03, CHRD-04, CHRD-05
**Success Criteria** (what must be TRUE):

  1. Pressing T+H+E within 50ms is detected as chord "eht" (sorted-alpha key)
  2. Pressing the same keys in any order (H+T+E, E+H+T, etc.) produces the same chord key
  3. A chord is only evaluated after all held keys are released, not on first keydown
  4. Pressing only 2 keys simultaneously does not trigger chord evaluation
  5. An unmatched chord replays all original keystrokes in order with no key loss
  6. `make build && make test` passes (ChordEngine unit tests covering all state machine paths)

**Plans:** 2 plans
Plans:
**Wave 1**

- [x] 04-01-PLAN.md -- ChordEngine state machine (TDD): ChordResult enum, 3-state machine, timing window, sorted-alpha encoding, replay with re-entry guard, AppDelegate wiring, unit tests

**Wave 2**

- [ ] 04-02-PLAN.md -- Human verification: transparent pass-through, no deadlock, modifier shortcuts work

### Phase 5: Dictionary System

**Goal**: JSON dictionaries load from disk, normalize chord keys to sorted-alpha format, support hot-reload, and include English and Thai word sets
**Mode:** mvp
**Depends on**: Phase 4
**Requirements**: DICT-01, DICT-02, DICT-03, DICT-04, DICT-05
**Success Criteria** (what must be TRUE):

  1. DictionaryStore loads english.json and thai.json from Resources/dictionaries/ on launch
  2. Chord key "eht" returns "the" from the English dictionary via O(1) lookup
  3. Editing english.json on disk triggers a hot-reload within 1 second (no app restart)
  4. The English dictionary contains at least 150 entries; Thai dictionary at least 100 entries
  5. `make build && make test` passes (DictionaryLoader and DictionaryWatcher unit tests)

**Plans**: TBD

### Phase 6: Text Output

**Goal**: A matched chord suppresses its original keystrokes and types the full word, with smart space handling
**Mode:** mvp
**Depends on**: Phase 5
**Requirements**: TXTO-01, TXTO-02, TXTO-03, TXTO-04, TXTO-05
**Success Criteria** (what must be TRUE):

  1. Typing a matched chord (e.g. T+H+E) in TextEdit outputs "the " (word + space) with no stray characters
  2. Typing a matched Thai chord in TextEdit outputs the correct Thai Unicode word
  3. Typing "the " followed by "." results in "the." (smart space removed before punctuation)
  4. Synthetic output events are marked to prevent re-entry into the chord engine
  5. `make build && make test` passes (EventOutputter unit tests for ASCII, Thai, and smart space)

**Plans**: TBD

### Phase 7: Global Toggle

**Goal**: The user can pause and resume chord typing from the menubar or via Cmd+Shift+Space, and pausing lets all keystrokes pass through completely
**Mode:** mvp
**Depends on**: Phase 6
**Requirements**: TOGL-01, TOGL-02, TOGL-03, TOGL-04
**Success Criteria** (what must be TRUE):

  1. Clicking the menubar icon toggles between active and paused states and the icon updates visually
  2. Pressing Cmd+Shift+Space while any app is frontmost toggles active/paused
  3. When paused, all keystrokes appear normally in any target app with zero interference
  4. `make build && make test` passes (toggle state unit tests)

**Plans**: TBD
**UI hint**: yes

### Phase 8: Settings Window

**Goal**: A macOS preferences window exposes timing, dictionary enable/disable, app filter mode, and shortcut display
**Mode:** mvp
**Depends on**: Phase 7
**Requirements**: SETT-01, SETT-02, SETT-03, SETT-04, SETT-05
**Success Criteria** (what must be TRUE):

  1. Settings opens as a standard macOS preferences window (not a floating panel)
  2. Dragging the timing slider immediately changes the chord detection window (20-200ms range)
  3. Toggling English or Thai dictionary disables chord detection for that language
  4. App Filter section shows blacklist/whitelist mode toggle and an app list with add/remove controls
  5. Shortcut section displays "Cmd+Shift+Space" as the current global toggle shortcut
  6. `make build && make test` passes (Settings model persistence unit tests)

**Plans**: TBD
**UI hint**: yes

### Phase 9: App Blacklist/Whitelist

**Goal**: Chord detection is automatically gated by a per-app filter list stored in UserDefaults
**Mode:** mvp
**Depends on**: Phase 8
**Requirements**: FILT-01, FILT-02, FILT-03, FILT-04
**Success Criteria** (what must be TRUE):

  1. In blacklist mode, chords are suppressed in a listed app and active everywhere else
  2. In whitelist mode, chords are active only in listed apps
  3. User can add an app by selecting from running apps or typing a bundle ID
  4. The filter list persists across app restarts (stored in UserDefaults)
  5. `make build && make test` passes (AppFilter unit tests for blacklist and whitelist logic)

**Plans**: TBD

### Phase 10: Polish + Packaging

**Goal**: The app guides users through Accessibility permission setup, detects secure text input, and ships as a signed DMG built with `make dmg`
**Mode:** mvp
**Depends on**: Phase 9
**Requirements**: SECR-01, SECR-02, DIST-01, DIST-02, DIST-03, DIST-04
**Success Criteria** (what must be TRUE):

  1. Typing in a password field (secure text input active) produces no chord substitutions
  2. A chord that starts forming before a password field gains focus is flushed cleanly on focus change
  3. `make dmg` produces ChordTyper-1.0.dmg containing the app bundle and an Applications symlink
  4. The app runs on macOS 13 Ventura and macOS 14 Sonoma on both Apple Silicon and Intel
  5. First launch without Accessibility permission shows a clear in-app guidance screen
  6. `make build && make test` passes (SecureInputMonitor unit tests, DMG artifact check)

**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Project Scaffold | 1/1 | Complete | 2026-05-18 |
| 2. Menubar Skeleton | 2/2 | Complete | 2026-05-20 |
| 3. CGEventTap | 2/2 | Complete | 2026-05-22 |
| 4. Chord Detection | 0/2 | Not started | - |
| 5. Dictionary System | 0/TBD | Not started | - |
| 6. Text Output | 0/TBD | Not started | - |
| 7. Global Toggle | 0/TBD | Not started | - |
| 8. Settings Window | 0/TBD | Not started | - |
| 9. App Blacklist/Whitelist | 0/TBD | Not started | - |
| 10. Polish + Packaging | 0/TBD | Not started | - |
