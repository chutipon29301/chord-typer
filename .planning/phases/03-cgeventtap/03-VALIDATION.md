---
phase: 3
slug: cgeventtap
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-21
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (system, no install) |
| **Config file** | project.yml (ChordTyperTests target) |
| **Quick run command** | `make test` |
| **Full suite command** | `make build && make test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `make test`
- **After every plan wave:** Run `make build && make test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | EVNT-01 | — | N/A | unit | `make test` | Wave 0 | ⬜ pending |
| 03-01-02 | 01 | 1 | EVNT-02 | — | N/A | unit | `make test` | Wave 0 | ⬜ pending |
| 03-01-03 | 01 | 1 | EVNT-03 | — | TCC permission check gate | unit | `make test` | Wave 0 | ⬜ pending |
| 03-01-04 | 01 | 1 | EVNT-04 | — | N/A | unit | `make test` | Wave 0 | ⬜ pending |
| 03-01-05 | 01 | 1 | EVNT-05 | — | N/A | unit | `make test` | Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `Tests/ChordTyperTests/EventTapManagerTests.swift` — unit tests for EVNT-01 through EVNT-05
- [ ] Injectable `tapCreator` closure on `EventTapManager` — enables unit tests without real CGEventTap (avoids TCC dependency in test context)

*Existing infrastructure (XCTest, project.yml test target) covers framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Keystrokes appear unchanged in frontmost app | EVNT-01 | Requires real CGEventTap with Accessibility permission | Build app, grant Accessibility, type in any text editor — all keys pass through |
| Permission alert shows when Accessibility not granted | EVNT-03 | Requires real macOS TCC prompt | Build app, revoke Accessibility, launch — alert appears with "Open Settings" button |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
