# Requirements: ChordTyper

**Defined:** 2026-05-18
**Core Value:** Chord-based typing must reliably detect simultaneous keypresses and output the correct word, replacing the original keystrokes seamlessly

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Scaffold

- [x] **SCAF-01**: Project uses xcodegen (project.yml) to generate .xcodeproj from CLI
- [x] **SCAF-02**: Makefile provides build, run, dmg, clean targets
- [x] **SCAF-03**: Folder structure matches spec (Sources/, Resources/, dictionaries/)
- [x] **SCAF-04**: Info.plist sets LSUIElement=YES (no Dock icon)
- [x] **SCAF-05**: Entitlements file includes accessibility permissions

### Menubar

- [x] **MENU-01**: App launches as menubar-only (no Dock icon, no main window)
- [x] **MENU-02**: Menubar icon uses SF Symbol (keyboard) with active/paused visual states
- [x] **MENU-03**: Menubar dropdown shows active/paused toggle, dictionary toggles, Settings, Open Dictionary Folder, Quit
- [x] **MENU-04**: User can quit app from menubar menu

### Event Tap

- [x] **EVNT-01**: CGEventTap created at session level (kCGSessionEventTap + kCGHeadInsertEventTap)
- [x] **EVNT-02**: Tap intercepts keyDown and keyUp events
- [x] **EVNT-03**: App checks AXIsProcessTrusted() and guides user to System Settings if permission missing
- [x] **EVNT-04**: Tap handles kCGEventTapDisabledByTimeout by re-enabling
- [x] **EVNT-05**: Tap recovers after sleep/wake via NSWorkspace notification

### Chord Detection

- [ ] **CHRD-01**: Chord detection uses configurable timing window (50ms default, 20-200ms range)
- [ ] **CHRD-02**: Minimum 3 keys required to trigger chord evaluation
- [ ] **CHRD-03**: Key order does not matter (T+H+E = H+E+T = E+T+H)
- [ ] **CHRD-04**: Chord evaluated on all-keys-released, not on keydown
- [ ] **CHRD-05**: Unmatched chord passes through all keys in original order (no keystroke loss)

### Dictionary

- [ ] **DICT-01**: Dictionaries stored as UTF-8 JSON in Resources/dictionaries/
- [ ] **DICT-02**: Chord keys stored as sorted-alphabetical lowercase for O(1) lookup
- [ ] **DICT-03**: English dictionary covers ~150 most common words (ZipChord-compatible)
- [ ] **DICT-04**: Thai dictionary covers ~100 most common words (QWERTY key codes to Thai Unicode)
- [ ] **DICT-05**: App hot-reloads dictionaries on file change (DispatchSource)

### Text Output

- [ ] **TXTO-01**: Matched chord suppresses original keystrokes (return nil from tap)
- [ ] **TXTO-02**: Matched word output via CGEventPost (English) or NSPasteboard fallback (Thai)
- [ ] **TXTO-03**: Smart space auto-appended after chord word output
- [ ] **TXTO-04**: Smart space removed before punctuation (. , ! ? : ; ) ] } ' " ...)
- [ ] **TXTO-05**: Synthetic events marked to prevent re-entry into chord detection

### Toggle

- [ ] **TOGL-01**: User can toggle active/paused from menubar click
- [ ] **TOGL-02**: Global keyboard shortcut Cmd+Shift+Space toggles active/paused
- [ ] **TOGL-03**: Toggle works when any app is frontmost
- [ ] **TOGL-04**: All keystrokes pass through with zero interference when paused

### Settings

- [ ] **SETT-01**: Settings opens as standard macOS preferences window
- [ ] **SETT-02**: General section: timing window slider (20-200ms), launch at login toggle
- [ ] **SETT-03**: Dictionaries section: enable/disable English, enable/disable Thai, Open Dictionary Folder button
- [ ] **SETT-04**: App Filter section: blacklist/whitelist mode toggle, app list with add/remove
- [ ] **SETT-05**: Shortcut section: display current shortcut (Cmd+Shift+Space)

### App Filter

- [ ] **FILT-01**: User can choose blacklist mode (active everywhere except listed apps) or whitelist mode
- [ ] **FILT-02**: User can add apps from running apps or by typing bundle ID
- [ ] **FILT-03**: Filter list stored in UserDefaults as array of bundle identifiers
- [ ] **FILT-04**: Filter checked on every chord evaluation via frontmostApplication.bundleIdentifier

### Security

- [ ] **SECR-01**: Chord detection disabled when secure text input is active (password fields)
- [ ] **SECR-02**: Chord state flushed when SecureEventInput activates mid-chord

### Distribution

- [ ] **DIST-01**: App ad-hoc signed (CODE_SIGN_IDENTITY="-", no Apple Developer account)
- [ ] **DIST-02**: make dmg produces ChordTyper-1.0.dmg with app + Applications symlink
- [ ] **DIST-03**: App detects missing Accessibility permission and shows clear guidance
- [ ] **DIST-04**: macOS 13 Ventura+ supported (Apple Silicon + Intel)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### UX Enhancements

- **UX-01**: In-app chord editor / dictionary GUI
- **UX-02**: Chord hints overlay / floating tooltip
- **UX-03**: Typing statistics / keystroke savings counter
- **UX-04**: Customizable global shortcut (remapping from Cmd+Shift+Space)

### Distribution

- **DIST2-01**: Apple Developer signing + notarization
- **DIST2-02**: Cloud sync of dictionaries

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| iOS / iPadOS support | CGEventTap doesn't exist on iOS; entirely different architecture |
| Sequential text expansion (shorthands) | Different input model; macOS system text replacement handles this natively |
| Multiple dictionaries per language | Over-engineering for single user; merge JSON manually |
| Real-time chat / collaborative features | Personal utility, not a social product |
| Third-party dependencies | Design constraint; Apple frameworks only |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SCAF-01 | Phase 1 | Complete |
| SCAF-02 | Phase 1 | Complete |
| SCAF-03 | Phase 1 | Complete |
| SCAF-04 | Phase 1 | Complete |
| SCAF-05 | Phase 1 | Complete |
| MENU-01 | Phase 2 | Complete |
| MENU-02 | Phase 2 | Complete |
| MENU-03 | Phase 2 | Complete |
| MENU-04 | Phase 2 | Complete |
| EVNT-01 | Phase 3 | Complete |
| EVNT-02 | Phase 3 | Complete |
| EVNT-03 | Phase 3 | Complete |
| EVNT-04 | Phase 3 | Complete |
| EVNT-05 | Phase 3 | Complete |
| CHRD-01 | Phase 4 | Pending |
| CHRD-02 | Phase 4 | Pending |
| CHRD-03 | Phase 4 | Pending |
| CHRD-04 | Phase 4 | Pending |
| CHRD-05 | Phase 4 | Pending |
| DICT-01 | Phase 5 | Pending |
| DICT-02 | Phase 5 | Pending |
| DICT-03 | Phase 5 | Pending |
| DICT-04 | Phase 5 | Pending |
| DICT-05 | Phase 5 | Pending |
| TXTO-01 | Phase 6 | Pending |
| TXTO-02 | Phase 6 | Pending |
| TXTO-03 | Phase 6 | Pending |
| TXTO-04 | Phase 6 | Pending |
| TXTO-05 | Phase 6 | Pending |
| TOGL-01 | Phase 7 | Pending |
| TOGL-02 | Phase 7 | Pending |
| TOGL-03 | Phase 7 | Pending |
| TOGL-04 | Phase 7 | Pending |
| SETT-01 | Phase 8 | Pending |
| SETT-02 | Phase 8 | Pending |
| SETT-03 | Phase 8 | Pending |
| SETT-04 | Phase 8 | Pending |
| SETT-05 | Phase 8 | Pending |
| FILT-01 | Phase 9 | Pending |
| FILT-02 | Phase 9 | Pending |
| FILT-03 | Phase 9 | Pending |
| FILT-04 | Phase 9 | Pending |
| SECR-01 | Phase 10 | Pending |
| SECR-02 | Phase 10 | Pending |
| DIST-01 | Phase 10 | Pending |
| DIST-02 | Phase 10 | Pending |
| DIST-03 | Phase 10 | Pending |
| DIST-04 | Phase 10 | Pending |

**Coverage:**
- v1 requirements: 44 total
- Mapped to phases: 44
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-18*
*Last updated: 2026-05-18 after initial definition*
