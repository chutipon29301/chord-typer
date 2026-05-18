---
phase: 01-project-scaffold
plan: 01
status: complete
completed: 2026-05-18
commits:
  - 37b416a feat(01-01): create project scaffold files
  - 509978c feat(01-01): verify build and test pipeline
---

# Plan 01-01 Summary: Project Scaffold

## What Was Done

Created the complete ChordTyper project scaffold as a CLI-buildable macOS menubar app.

### Files Created
| File | Purpose |
|------|---------|
| `project.yml` | xcodegen config — generates .xcodeproj with correct bundle ID, entitlements, signing |
| `Makefile` | Build orchestration: generate, build, run, test, dmg, clean targets |
| `Sources/ChordTyper/ChordTyperApp.swift` | @main App struct with MenuBarExtra stub |
| `Resources/Info.plist` | App bundle metadata (LSUIElement=YES) |
| `Resources/ChordTyper.entitlements` | Accessibility permission declaration |
| `Resources/dictionaries/.gitkeep` | Placeholder for Phase 5 dictionary files |
| `Tests/ChordTyperTests/ChordTyperSmokeTests.swift` | Smoke test verifying test pipeline |
| `.gitignore` | Excludes *.xcodeproj and .build/ |

### Tasks Completed
1. **Install xcodegen + create all project files** — xcodegen 2.45.4 installed via Homebrew; all 7 source/config files created per locked decisions D-01 through D-09
2. **Build and test verification** — `make build` BUILD SUCCEEDED, `make test` TEST SUCCEEDED (1 test, 0 failures)
3. **Human verification** — App launches in menubar with no Dock icon, shows "ChordTyper is running", Quit button works. **Approved by user.**

## Deviations

| # | Type | Description | Resolution |
|---|------|-------------|------------|
| 1 | Blocking | xcodegen overwrites entitlements plist on `generate` — raw plist content was lost | Moved accessibility key to `project.yml` `entitlements.properties` so xcodegen generates it correctly |
| 2 | Blocking | Test target needed `GENERATE_INFOPLIST_FILE: YES` for code signing | Added build setting to test target in project.yml |

## Verification Results

- `xcodegen --version` — 2.45.4
- `make build` — BUILD SUCCEEDED (ad-hoc signed, Release config)
- `make test` — TEST SUCCEEDED (1 test executed, 0 failures)
- `make run` — App launches as menubar-only item, no Dock icon, Quit works
- All SCAF-01 through SCAF-05 requirements satisfied
- All locked decisions D-01 through D-09 implemented

## Requirements Coverage

| Requirement | Status |
|-------------|--------|
| SCAF-01: xcodegen generates valid .xcodeproj | Verified |
| SCAF-02: Makefile provides build/run/test/dmg/clean | Verified |
| SCAF-03: Folder structure matches spec | Verified |
| SCAF-04: LSUIElement=YES, no Dock icon | Verified (human) |
| SCAF-05: Entitlements declare accessibility | Verified |
