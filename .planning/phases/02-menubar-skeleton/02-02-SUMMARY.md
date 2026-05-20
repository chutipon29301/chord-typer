---
phase: 02-menubar-skeleton
plan: "02"
subsystem: menubar-ui
tags: [dictionaries, bundle-resources, xcodegen, os-log]
dependency_graph:
  requires:
    - phase: 02-01
      provides: ChordTyperApp.swift menubar structure with Open Dictionary Folder button
  provides: [placeholder-english-dict, placeholder-thai-dict, dictionary-folder-guard]
  affects: [Phase5-DictionarySystem]
tech_stack:
  added: []
  patterns: [folder-reference-resources, filemanager-guard-before-open]
key_files:
  created:
    - Resources/dictionaries/english.json
    - Resources/dictionaries/thai.json
    - Tests/ChordTyperTests/DictionaryBundleTests.swift
  modified:
    - Sources/ChordTyper/ChordTyperApp.swift
    - project.yml
decisions:
  - "project.yml resources must use type: folder + buildPhase: resources for xcodegen to create Copy Bundle Resources phase"
  - "english.json ships with 4 sample chords (eht→the, adn→and, ehs→she, eho→hoe) — Phase 5 replaces with full 150-entry set"
patterns_established:
  - "Folder reference pattern: add resource directories under sources with type: folder and buildPhase: resources in project.yml"
requirements_completed: [MENU-03]
gap_closure: true
metrics:
  duration_minutes: 5
  completed: "2026-05-20T09:10:00Z"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 6
---

# Phase 02 Plan 02: Gap Closure Summary

**Placeholder dictionary JSON files and FileManager guard fix Open Dictionary Folder action that silently failed on empty bundle directory**

## Performance

- **Duration:** ~5 min
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added english.json (4 sample chord entries) and thai.json (empty object) to Resources/dictionaries/
- Fixed project.yml to use `type: folder` + `buildPhase: resources` so xcodegen generates Copy Bundle Resources phase
- Guarded Open Dictionary Folder button with `FileManager.default.fileExists` check and `logger.warning` on missing path
- Added `DictionaryBundleTests` verifying bundled JSON file validity

## Test Results

```
Test Suite 'All tests' passed
  ChordTyperSmokeTests: 1 test passed
  DictionaryBundleTests: 1 test passed
  MenuStateTests: 6 tests passed
Total: 8 tests, 0 failures
```

`make build` — BUILD SUCCEEDED
`make test` — TEST SUCCEEDED

## Files Changed

| File | Change |
|------|--------|
| `Resources/dictionaries/english.json` | Created — 4 sample chord entries |
| `Resources/dictionaries/thai.json` | Created — empty JSON object |
| `Resources/dictionaries/.gitkeep` | Deleted — replaced by real files |
| `Sources/ChordTyper/ChordTyperApp.swift` | FileManager guard on Open Dictionary Folder |
| `project.yml` | Fixed resources config: type: folder, buildPhase: resources |
| `Tests/ChordTyperTests/DictionaryBundleTests.swift` | Created — bundle dictionary validation test |

## Commits

| Hash | Message |
|------|---------|
| b133ae3 | fix(02-02): close gap — placeholder dictionaries and Open Dictionary Folder guard |

## Deviations from Plan

**xcodegen resources config required type: folder + buildPhase: resources** — the original `resources:` block in project.yml did not generate a Copy Bundle Resources build phase. Changed to include dictionaries as a source with `type: folder` and `buildPhase: resources`. This is the correct xcodegen pattern for folder references.

## Issues Encountered

- Initial test used `Bundle(for: type(of: self))` which returns the test bundle, not the host app. Fixed to use `Bundle.main` which points to the host app during test execution.

## Next Phase Readiness

- Phase 2 fully complete — all UAT gaps closed
- Dictionaries folder reliably present in app bundle for Phase 5 (Dictionary System)

---
*Phase: 02-menubar-skeleton*
*Completed: 2026-05-20*
