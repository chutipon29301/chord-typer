# Phase 1: Project Scaffold - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-18
**Phase:** 1-Project Scaffold
**Areas discussed:** Entry point pattern, Test target scope, Swift concurrency mode, Bundle ID convention

---

## Entry Point Pattern

### Question 1: How should the app bootstrap?

| Option | Description | Selected |
|--------|-------------|----------|
| @main App struct | Pure SwiftUI entry with MenuBarExtra scene. Modern, minimal boilerplate. | ✓ |
| AppDelegate + NSApplication.main() | Traditional AppKit bootstrap with more lifecycle control. | |
| Hybrid — @main + AppDelegate adaptor | SwiftUI @main with @NSApplicationDelegateAdaptor for lifecycle hooks. | |

**User's choice:** @main App struct
**Notes:** Selected preview included @NSApplicationDelegateAdaptor pattern, but decided to defer that to Phase 2.

### Question 2: Minimal stub or full skeleton?

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal stub | @main with placeholder MenuBarExtra. Phase 2 adds real UI. | ✓ |
| Full skeleton with all scenes | MenuBarExtra + Settings scene + AppDelegate adaptor upfront. | |

**User's choice:** Minimal stub
**Notes:** None

---

## Test Target Scope

### Question 1: What should the skeleton test target contain?

| Option | Description | Selected |
|--------|-------------|----------|
| Smoke test only | One XCTestCase verifying test pipeline works. | ✓ |
| Empty placeholder per file | Stub test files for each planned source file. | |
| Build verification test | Subprocess test running xcodebuild. | |

**User's choice:** Smoke test only
**Notes:** None

---

## Swift Concurrency Mode

### Question 1: Swift 6 strict concurrency from day one?

| Option | Description | Selected |
|--------|-------------|----------|
| Strict from day one | SWIFT_STRICT_CONCURRENCY=complete. Every file concurrency-safe from start. | ✓ |
| Targeted warnings first | SWIFT_STRICT_CONCURRENCY=targeted. Switch to complete in Phase 3-4. | |

**User's choice:** Strict from day one
**Notes:** None

---

## Bundle ID Convention

### Question 1: What bundle identifier format?

| Option | Description | Selected |
|--------|-------------|----------|
| dev.chutipon.ChordTyper | Reverse-domain of chutipon.dev, mixed case. | |
| dev.chutipon.chordtyper | Reverse-domain of chutipon.dev, all lowercase. | ✓ |

**User's choice:** dev.chutipon.chordtyper
**Notes:** User owns chutipon.dev domain. Prefers all lowercase bundle identifier.

---

## Claude's Discretion

None — user made all decisions directly.

## Deferred Ideas

None — discussion stayed within phase scope.
