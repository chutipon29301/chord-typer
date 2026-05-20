---
status: diagnosed
phase: 02-menubar-skeleton
source: [02-01-SUMMARY.md]
started: 2026-05-20T10:00:00Z
updated: 2026-05-20T10:15:00Z
---

## Current Test

[testing complete]

## Tests

### 1. No Dock Icon
expected: After `make run`, the app launches with no Dock icon. Only the menubar icon appears.
result: pass

### 2. Menubar Icon Shows Active State
expected: The menubar shows a `keyboard.fill` SF Symbol icon (solid keyboard) indicating ChordTyper is active.
result: pass

### 3. Full Menu Structure
expected: Clicking the menubar icon shows a dropdown with: "Enable ChordTyper" toggle (checked), "Dictionaries >" submenu, "Settings...", "Open Dictionary Folder", and "Quit ChordTyper".
result: pass

### 4. Toggle Enable ChordTyper
expected: Clicking "Enable ChordTyper" unchecks it and the menubar icon changes to `keyboard.badge.ellipsis` (keyboard with dots). Clicking again re-enables and icon returns to `keyboard.fill`.
result: pass

### 5. Dictionaries Submenu
expected: Hovering/clicking "Dictionaries >" opens a submenu with "English" and "Thai" toggles, both checked by default.
result: pass

### 6. Open Dictionary Folder
expected: Clicking "Open Dictionary Folder" opens Finder to the `Resources/dictionaries/` folder inside the app bundle.
result: issue
reported: "it does not open anything"
severity: major

### 7. Quit ChordTyper
expected: Clicking "Quit ChordTyper" terminates the app cleanly. The menubar icon disappears.
result: pass

### 8. State Persistence Across Relaunch
expected: Disable ChordTyper toggle, quit, relaunch with `make run`. The toggle remains unchecked and the icon shows the paused state (`keyboard.badge.ellipsis`).
result: pass

## Summary

total: 8
passed: 7
issues: 1
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "Clicking 'Open Dictionary Folder' opens Finder to the Resources/dictionaries/ folder inside the app bundle"
  status: failed
  reason: "User reported: it does not open anything"
  severity: major
  test: 6
  root_cause: "The dictionaries folder contains only .gitkeep (no real files). xcodebuild does not copy empty/gitkeep-only folders into the app bundle Resources. Bundle.main.resourceURL?.appendingPathComponent('dictionaries') resolves to a non-existent path, and NSWorkspace.shared.open(url) silently fails on non-existent paths."
  artifacts:
    - path: "Sources/ChordTyper/ChordTyperApp.swift"
      issue: "NSWorkspace.shared.open(url) silently fails when dictionaries dir missing from bundle — no user feedback"
    - path: "Resources/dictionaries/.gitkeep"
      issue: "Only .gitkeep present — no real dictionary files, so folder not copied into bundle"
  missing:
    - "Add a placeholder dictionary file (e.g. english.json with minimal entries) so the folder gets copied into the bundle"
    - "Add a fallback/error log or user alert when the dictionaries URL does not exist"
  debug_session: ""
