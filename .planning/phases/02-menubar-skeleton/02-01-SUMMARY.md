---
phase: 02-menubar-skeleton
plan: "01"
subsystem: menubar-ui
tags: [menubar, swiftui, appstorage, menubarextra, tdd]
dependency_graph:
  requires: []
  provides: [AppStorage-chordTyperEnabled, AppStorage-englishEnabled, AppStorage-thaiEnabled, MenuBarExtra-full-structure]
  affects: [Phase3-EventTap, Phase5-DictionaryManager]
tech_stack:
  added: [os.Logger, AppKit.NSWorkspace, AppKit.NSApplication]
  patterns: [MenuBarExtra-menu-style, AppStorage-bool-defaults, file-scope-logger]
key_files:
  created:
    - Tests/ChordTyperTests/MenuStateTests.swift
  modified:
    - Sources/ChordTyper/ChordTyperApp.swift
decisions:
  - "D-06/D-07: keyboard.fill (active) / keyboard.badge.ellipsis (paused) as menubar icon"
  - "D-09: No @NSApplicationDelegateAdaptor — pure SwiftUI MenuBarExtra handles all Phase 2 UI"
  - "D-10/D-11/D-13: @AppStorage keys chordTyperEnabled, englishEnabled, thaiEnabled default true"
  - "D-14: Settings... stub logs via os_log only — no window until Phase 8"
  - "D-15: Open Dictionary Folder uses Bundle.main.resourceURL + NSWorkspace.shared.open"
metrics:
  duration_minutes: 30
  completed: "2026-05-18T18:00:21Z"
  tasks_completed: 1
  tasks_total: 2
  files_changed: 2
---

# Phase 02 Plan 01: Menubar Skeleton Summary

**One-liner:** Full menubar SwiftUI app with dynamic keyboard icon, wired toggles, dictionaries submenu, and @AppStorage-persisted state using MenuBarExtra(.menu).

## What Was Built

Evolved `ChordTyperApp.swift` from a minimal stub (Text + single Quit button) into a fully wired macOS menubar-only app:

- **Dynamic icon** via `menuBarIcon` computed property: `keyboard.fill` when `chordTyperEnabled=true`, `keyboard.badge.ellipsis` when false
- **Full menu structure** per D-01 through D-16:
  - `Toggle("Enable ChordTyper")` bound to `@AppStorage("chordTyperEnabled")`
  - `Menu("Dictionaries")` submenu with `Toggle("English")` and `Toggle("Thai")` bound to their respective `@AppStorage` keys
  - `Button("Settings...")` logging via `Logger(subsystem:category:)`
  - `Button("Open Dictionary Folder")` using `Bundle.main.resourceURL?.appendingPathComponent("dictionaries")` + `NSWorkspace.shared.open`
  - `Button("Quit ChordTyper")` calling `NSApplication.shared.terminate(nil)`
- **Logger** at file scope: `Logger(subsystem: "dev.chutipon.chordtyper", category: "AppMenu")`
- **Three @AppStorage properties** establishing the cross-phase state interface consumed by Phase 3 and Phase 5

Created `MenuStateTests.swift` with 6 unit tests covering:
- Icon name logic: active → `keyboard.fill`, paused → `keyboard.badge.ellipsis`
- AppStorage defaults: all three keys absent on fresh install (proving default=true governs)
- UserDefaults round-trip: `set(false)` → `bool(forKey:)` returns `false`

## Test Results

```
Test Suite 'All tests' passed
  ChordTyperSmokeTests: 1 test passed
  MenuStateTests: 6 tests passed
Total: 7 tests, 0 failures
```

`make build` — BUILD SUCCEEDED
`make test` — TEST SUCCEEDED

## Files Changed

| File | Change |
|------|--------|
| `Sources/ChordTyper/ChordTyperApp.swift` | Evolved from 14-line stub to full menubar app (49 lines) |
| `Tests/ChordTyperTests/MenuStateTests.swift` | Created — 6 tests for icon logic and AppStorage defaults |

## Commits

| Hash | Message |
|------|---------|
| 9bf2a25 | feat(02-01): menubar skeleton with full menu structure and unit tests |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

- `Button("Settings...")` — logs via os_log only; no settings window. Intentional — Phase 8 will implement the settings UI. This does not block the plan goal (menubar shell).

## Task 2 Status: Pending Human Checkpoint

**Task 2 (checkpoint:human-verify)** requires visual inspection:
1. Run `make run` and verify no Dock icon appears
2. Verify menubar shows `keyboard.fill` icon
3. Click menubar icon — verify full menu structure matches UI-SPEC
4. Toggle "Enable ChordTyper" — verify icon switches to `keyboard.badge.ellipsis`
5. Open "Dictionaries >" submenu — verify English and Thai toggles with checkmarks
6. Click "Open Dictionary Folder" — verify Finder opens `Resources/dictionaries/`
7. Click "Quit ChordTyper" — verify app terminates
8. Relaunch — verify toggle states persisted

Type "approved" or describe issues to continue.

## Threat Flags

None — this plan introduces no network endpoints, auth paths, file access patterns (beyond read-only bundle resource URL), or schema changes at trust boundaries. The `NSWorkspace.shared.open(url)` call uses a `Bundle.main.resourceURL` path (read-only bundle, no user-supplied input).

## Self-Check: PASSED

- [x] `Sources/ChordTyper/ChordTyperApp.swift` exists and contains all required elements
- [x] `Tests/ChordTyperTests/MenuStateTests.swift` exists with 6 tests
- [x] Commit 9bf2a25 verified in git log
- [x] `make build` exits 0
- [x] `make test` exits 0, all 7 tests pass
