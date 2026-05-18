---
phase: 2
slug: menubar-skeleton
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-19
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode 16.4) |
| **Config file** | `project.yml` (test target: ChordTyperTests) |
| **Quick run command** | `make test` |
| **Full suite command** | `make test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `make test`
- **After every plan wave:** Run `make test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | MENU-01 | — | N/A | unit | `make test` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | MENU-02 | — | N/A | unit | `make test` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | MENU-03 | — | N/A | unit | `make test` | ❌ W0 | ⬜ pending |
| 02-01-04 | 01 | 1 | MENU-04 | — | N/A | unit | `make test` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `Tests/ChordTyperTests/MenuStateTests.swift` — stubs for MENU-01 through MENU-04 (icon state logic, menu item state, toggle behavior)

*Existing infrastructure covers test framework — only test file creation needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| App appears only in menubar (no Dock icon) | MENU-01 | Requires visual check of running app | Launch app, verify no Dock icon, verify menubar icon visible |
| Open Dictionary Folder opens Finder | MENU-03 | Requires Finder interaction | Click "Open Dictionary Folder", verify Finder opens to dictionaries/ |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
