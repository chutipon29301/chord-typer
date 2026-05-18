# ChordTyper

## What This Is

A macOS menubar app that enables chord-based typing on a standard Mac keyboard. Press 3+ keys simultaneously; if the combination matches a dictionary entry, the app suppresses individual keystrokes and outputs the full word. Designed for faster everyday prose — chatting with AI, writing prompts — not developer snippets.

## Core Value

Chord-based typing must reliably detect simultaneous keypresses and output the correct word, replacing the original keystrokes seamlessly — this is the one thing that must work.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] CGEventTap intercepts keystrokes at driver level before macOS IME
- [ ] Chord detection with configurable timing window (50ms default, 20-200ms range)
- [ ] Key-order-independent chord matching (T+H+E = H+E+T = E+T+H)
- [ ] Chord evaluated on all-keys-released, not on keydown
- [ ] Unmatched chords pass through all keys normally
- [ ] JSON-based dictionary with sorted-alphabetical key encoding
- [ ] English dictionary (~150 common words, ZipChord-compatible)
- [ ] Thai dictionary (~100 common words, QWERTY key codes to Thai Unicode)
- [ ] Hot-reload dictionaries on file change (DispatchSource)
- [ ] Smart space: auto-append space after chord word, remove before punctuation
- [ ] Menubar icon with active/paused state and dropdown menu
- [ ] Global toggle shortcut (Cmd+Shift+Space)
- [ ] Settings window: timing slider, dictionary toggles, app filter, shortcut display
- [ ] Per-app blacklist/whitelist filtering by bundle ID
- [ ] Secure text input detection (disable in password fields)
- [ ] Accessibility permission detection and user guidance
- [ ] Ad-hoc signed DMG packaging via `make dmg`
- [ ] macOS 13 Ventura+, Apple Silicon + Intel
- [ ] No third-party dependencies
- [ ] CLI-buildable (no Xcode GUI required)

### Out of Scope

- In-app chord editor / dictionary UI — edit JSON directly
- Chord hints overlay / visualizer — complexity without clear value for v1
- Typing statistics / keystroke savings counter — nice-to-have, not core
- Cloud sync of dictionaries — personal use, local files sufficient
- Apple Developer signing / notarization — personal use only
- iOS / iPadOS support — macOS-only for v1

## Context

- Built with Swift + SwiftUI, no third-party dependencies
- Uses CGEventTap for low-level keystroke interception — works regardless of active input method (critical for Thai IME compatibility)
- Build system: xcodegen for project generation, Make for build/run/package
- Dictionary format: UTF-8 JSON with sorted-alphabetical key encoding
- English chords sourced from ZipChord (MIT) for muscle memory compatibility
- Thai chords generated from NECTEC/Lexitron frequency corpus
- Target user: the developer themselves, for daily prose typing

## Constraints

- **Platform**: macOS 13 Ventura+ (Apple Silicon + Intel) — uses modern SwiftUI and CGEventTap APIs
- **Dependencies**: Zero third-party dependencies — Apple frameworks only
- **Build**: Must be fully CLI-buildable (xcodegen + make) — no Xcode GUI required
- **Signing**: Ad-hoc signing only (no Apple Developer account) — personal distribution
- **Performance**: Chord detection must be imperceptible (<50ms from release to output)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| CGEventTap over NSEvent | Driver-level interception works regardless of active IME (critical for Thai) | — Pending |
| Sorted-alphabetical key encoding | Order-independent matching with O(1) lookup | — Pending |
| Evaluate on all-keys-released | Prevents false positives during chord formation | — Pending |
| xcodegen + Make over raw Xcode | CLI-buildable, no GUI dependency, scriptable | — Pending |
| JSON dictionaries with hot-reload | User-editable, no rebuild required, simple format | — Pending |
| 10-phase implementation plan | Bottom-up: scaffold → event tap → detection → output → UI → polish | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-18 after initialization*
