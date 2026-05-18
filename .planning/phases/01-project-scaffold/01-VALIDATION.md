---
phase: 1
slug: project-scaffold
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-18
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode 26.5 bundled) |
| **Config file** | project.yml test target (`ChordTyperTests`) |
| **Quick run command** | `make test` |
| **Full suite command** | `make build && make test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `make build`
- **After every plan wave:** Run `make build && make test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | SCAF-01 | — | N/A | smoke | `xcodegen generate && echo OK` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | SCAF-02 | — | N/A | smoke | `make build` | ❌ W0 | ⬜ pending |
| 01-01-03 | 01 | 1 | SCAF-03 | — | N/A | smoke | `ls Sources/ChordTyper Resources Tests/ChordTyperTests` | ❌ W0 | ⬜ pending |
| 01-01-04 | 01 | 1 | SCAF-04 | — | N/A | manual | Launch app, verify no Dock icon | ❌ W0 | ⬜ pending |
| 01-01-05 | 01 | 1 | SCAF-05 | — | N/A | smoke | `grep accessibility Resources/ChordTyper.entitlements` | ❌ W0 | ⬜ pending |
| 01-01-06 | 01 | 1 | D-04 | — | N/A | unit | `make test` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `project.yml` — xcodegen configuration (SCAF-01)
- [ ] `Makefile` — build orchestration targets (SCAF-02)
- [ ] `Sources/ChordTyper/ChordTyperApp.swift` — @main entry point (needed for build)
- [ ] `Resources/Info.plist` — LSUIElement=YES (SCAF-04)
- [ ] `Resources/ChordTyper.entitlements` — accessibility declaration (SCAF-05)
- [ ] `Tests/ChordTyperTests/ChordTyperSmokeTests.swift` — smoke test (D-04)
- [ ] xcodegen install: `brew install xcodegen`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| No Dock icon visible | SCAF-04 | LSUIElement requires launching the built app visually | 1. `make run` 2. Verify no icon in Dock 3. Verify menubar icon present |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
