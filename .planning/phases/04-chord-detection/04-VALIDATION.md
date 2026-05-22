---
phase: 4
slug: chord-detection
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-22
---

# Phase 4 — Validation Strategy

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
- **After every plan wave:** Run `make build && make test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | CHRD-01 | — | N/A | unit | `make test` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | CHRD-02 | — | N/A | unit | `make test` | ❌ W0 | ⬜ pending |
| 04-01-03 | 01 | 1 | CHRD-03 | — | N/A | unit | `make test` | ❌ W0 | ⬜ pending |
| 04-01-04 | 01 | 1 | CHRD-04 | — | N/A | unit | `make test` | ❌ W0 | ⬜ pending |
| 04-01-05 | 01 | 1 | CHRD-05 | — | N/A | unit | `make test` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `Tests/ChordTyperTests/ChordEngineTests.swift` — stubs for CHRD-01 through CHRD-05
- [ ] Virtual keycode verification test — confirm US QWERTY keycode-to-character mapping

*Existing XCTest infrastructure from Phase 1-3 covers framework setup.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real-time chord typing feel | CHRD-01 | Subjective latency perception | Type T+H+E simultaneously in TextEdit, verify < 50ms perceived delay |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
