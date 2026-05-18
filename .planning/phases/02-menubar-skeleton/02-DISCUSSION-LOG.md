# Phase 2: Menubar Skeleton - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-19
**Phase:** 2-Menubar Skeleton
**Areas discussed:** Menu style, Icon states, AppDelegate need, Menu item stubs

---

## Menu style

### MenuBarExtra style

| Option | Description | Selected |
|--------|-------------|----------|
| .menu (Recommended) | Standard macOS dropdown menu — native feel, lightweight, matches utility apps | ✓ |
| .window (popover) | Custom SwiftUI popover panel — richer UI but heavier |  |

**User's choice:** .menu
**Notes:** None

### Menu structure grouping

| Option | Description | Selected |
|--------|-------------|----------|
| Flat with dividers | All items at top level, separated by dividers | |
| Dictionaries submenu | Dictionary toggles nested under a Dictionaries submenu | ✓ |

**User's choice:** Dictionaries submenu
**Notes:** Cleaner top level with dictionaries nested

### Toggle label

| Option | Description | Selected |
|--------|-------------|----------|
| "ChordTyper Active" | Checkmark appears/disappears, label stays same | |
| "Enable ChordTyper" | Checkmark = enabled, no checkmark = disabled | ✓ |
| You decide | Let Claude pick | |

**User's choice:** "Enable ChordTyper"
**Notes:** None

---

## Icon states

### Active vs paused distinction

| Option | Description | Selected |
|--------|-------------|----------|
| Same symbol, different fill | keyboard.fill (active) vs keyboard outline (paused) | |
| Different symbols | keyboard.fill (active) vs keyboard.badge.ellipsis (paused) | ✓ |
| You decide | Let Claude pick most readable at 18pt | |

**User's choice:** Different symbols
**Notes:** None

### Paused state SF Symbol

| Option | Description | Selected |
|--------|-------------|----------|
| keyboard.badge.ellipsis | Keyboard with '...' badge — suggests waiting/idle | ✓ |
| keyboard (outline only) | Same shape but hollow — subtle dimmed look | |
| pause.circle | Different symbol entirely — very obvious but breaks keyboard metaphor | |

**User's choice:** keyboard.badge.ellipsis
**Notes:** None

---

## AppDelegate need

### @NSApplicationDelegateAdaptor in Phase 2

| Option | Description | Selected |
|--------|-------------|----------|
| Not yet (Recommended) | Pure SwiftUI handles Phase 2; AppDelegate for Phase 3 | ✓ |
| Add it now | Add preemptively to avoid restructuring later | |

**User's choice:** Not yet
**Notes:** None

### State storage

| Option | Description | Selected |
|--------|-------------|----------|
| @AppStorage (Recommended) | Persists across restarts via UserDefaults | ✓ |
| @State (in-memory only) | Resets to active on every launch | |
| You decide | Let Claude pick | |

**User's choice:** @AppStorage
**Notes:** None

---

## Menu item stubs

### Non-functional item behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Fully wired to state (Recommended) | Toggle flips @AppStorage, icon changes, dict checkmarks toggle | ✓ |
| Disabled/grayed out | Items without backend are grayed out | |
| Log to console only | All items clickable but just log | |

**User's choice:** Fully wired to state
**Notes:** None

### Default state on first launch

| Option | Description | Selected |
|--------|-------------|----------|
| Active by default | App starts enabled — less friction | ✓ |
| Paused by default | App starts paused — safer, configure first | |
| You decide | Let Claude pick | |

**User's choice:** Active by default
**Notes:** None

### Open Dictionary Folder target

| Option | Description | Selected |
|--------|-------------|----------|
| App bundle Resources/dictionaries/ | Opens dictionaries inside built .app bundle | ✓ |
| ~/Library/Application Support/ChordTyper/dictionaries/ | User-writable location with copy-on-first-launch | |
| You decide | Let Claude pick | |

**User's choice:** App bundle Resources/dictionaries/
**Notes:** None

---

## Claude's Discretion

None — user made explicit choices for all decisions.

## Deferred Ideas

None — discussion stayed within phase scope.
