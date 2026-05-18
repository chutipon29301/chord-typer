# Phase 1: Project Scaffold - Pattern Map

**Mapped:** 2026-05-18
**Files analyzed:** 7 new files
**Analogs found:** 0 / 7 (greenfield — no existing codebase)

---

## File Classification

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `project.yml` | config | — | None | no-analog |
| `Makefile` | config | — | None | no-analog |
| `Sources/ChordTyper/ChordTyperApp.swift` | app-entry | request-response (SwiftUI lifecycle) | None | no-analog |
| `Resources/Info.plist` | config | — | None | no-analog |
| `Resources/ChordTyper.entitlements` | config | — | None | no-analog |
| `Resources/dictionaries/.gitkeep` | placeholder | — | None | no-analog |
| `Tests/ChordTyperTests/ChordTyperSmokeTests.swift` | test | — | None | no-analog |

All files are new. No existing source tree exists. Patterns are sourced from CLAUDE.md and RESEARCH.md Pattern sections.

---

## Pattern Assignments

### `project.yml` (config)

**Source:** RESEARCH.md Pattern 1 + CLAUDE.md project.yml skeleton

**Critical fields:**
- `SWIFT_VERSION: "6"` — enables Swift 6 language mode (strict concurrency by default)
- `SWIFT_STRICT_CONCURRENCY: complete` — D-06 decision; redundant in Swift 6 mode but harmless; include for explicitness
- `LSUIElement: true` — boolean `true`, not string `"YES"` (SCAF-04)
- `CODE_SIGN_IDENTITY: "-"` — ad-hoc signing (no Apple Developer account)
- `ENABLE_HARDENED_RUNTIME: NO` — required for ad-hoc; hardened runtime blocks CGEventPost
- Omit `xcodeVersion` field — installed Xcode is 26.5; CLAUDE.md documents 16.4; omitting skips version validation

**Full pattern** (from RESEARCH.md Pattern 1):
```yaml
name: ChordTyper
options:
  bundleIdPrefix: dev.chutipon
  deploymentTarget:
    macOS: "13.0"
  # xcodeVersion omitted — installed Xcode 26.5 does not match CLAUDE.md reference of 16.4

settings:
  SWIFT_VERSION: "6"
  SWIFT_STRICT_CONCURRENCY: complete      # D-06: explicit; no-op in Swift 6 mode
  MACOSX_DEPLOYMENT_TARGET: "13.0"
  ENABLE_HARDENED_RUNTIME: NO             # ad-hoc signing only

targets:
  ChordTyper:
    type: application
    platform: macOS
    sources:
      - path: Sources/ChordTyper
    resources:
      - path: Resources/dictionaries
    info:
      path: Resources/Info.plist
      properties:
        LSUIElement: true                 # SCAF-04: hides Dock icon
        CFBundleIdentifier: dev.chutipon.chordtyper    # D-08
        CFBundleVersion: "1"
        CFBundleShortVersionString: "1.0"
        NSAccessibilityUsageDescription: "ChordTyper needs Accessibility access to intercept keystrokes for chord detection."
    entitlements:
      path: Resources/ChordTyper.entitlements          # SCAF-05
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: dev.chutipon.chordtyper   # D-08/D-09
      CODE_SIGN_IDENTITY: "-"            # ad-hoc
      CODE_SIGN_STYLE: Manual
      CODE_SIGN_ENTITLEMENTS: Resources/ChordTyper.entitlements

  ChordTyperTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests/ChordTyperTests
    dependencies:
      - target: ChordTyper
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: dev.chutipon.chordtypertests
```

**Anti-patterns:**
- Do NOT add `com.apple.security.app-sandbox` to entitlements — blocks CGEventPost in future phases
- Do NOT set `xcodeVersion: "16.4"` — will produce mismatch warning against installed Xcode 26.5; omit the field

---

### `Makefile` (config)

**Source:** RESEARCH.md Pattern 4 + CLAUDE.md Makefile pattern

**Critical path:** `APP_PATH` must be `$(BUILD_DIR)/Build/Products/Release/$(SCHEME).app` — NOT `$(BUILD_DIR)/$(SCHEME).app`. The CLAUDE.md skeleton shows the shorter form, which is incorrect for xcodebuild `-derivedDataPath` layout.

**Full pattern** (from RESEARCH.md Pattern 4):
```makefile
SCHEME    = ChordTyper
BUILD_DIR = .build
APP_PATH  = $(BUILD_DIR)/Build/Products/Release/$(SCHEME).app

.PHONY: generate build run test dmg clean

generate:
	xcodegen generate

build: generate
	xcodebuild -scheme $(SCHEME) -configuration Release \
	  -derivedDataPath $(BUILD_DIR) build

run: build
	open "$(APP_PATH)"

test: generate
	xcodebuild -scheme $(SCHEME)Tests -configuration Debug \
	  -derivedDataPath $(BUILD_DIR) test

dmg: build
	codesign --force --deep -s - "$(APP_PATH)"
	hdiutil create -volname $(SCHEME) -srcfolder "$(APP_PATH)" \
	  -ov -format UDZO $(BUILD_DIR)/$(SCHEME).dmg

clean:
	rm -rf $(BUILD_DIR) *.xcodeproj
```

**Note on test scheme name:** After `xcodegen generate`, run `xcodebuild -list` to confirm the scheme name. xcodegen may generate `ChordTyperTests` or fold the test action into the `ChordTyper` scheme. Adjust `test` target accordingly.

**Makefile tab requirement:** Makefile recipe lines MUST use a literal tab character (not spaces). Editors that auto-convert tabs to spaces will break Make.

---

### `Sources/ChordTyper/ChordTyperApp.swift` (app-entry, SwiftUI lifecycle)

**Source:** RESEARCH.md Pattern 2 + CLAUDE.md file responsibilities + decisions D-01/D-02/D-03

**Constraints:**
- D-01: `MenuBarExtra` with placeholder text "ChordTyper is running" only
- D-02: No `@NSApplicationDelegateAdaptor` — added in Phase 2
- D-03: No `main.swift` — `@main` on this struct IS the entry point
- D-07: Swift 6 strict concurrency — no `@unchecked Sendable`

**Full pattern** (from RESEARCH.md Pattern 2):
```swift
// Sources/ChordTyper/ChordTyperApp.swift
import SwiftUI

@main
struct ChordTyperApp: App {
    var body: some Scene {
        MenuBarExtra("ChordTyper", systemImage: "keyboard") {
            Text("ChordTyper is running")
                .padding()
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)
    }
}
```

**Swift 6 concurrency note:** This struct has no stored mutable properties and is `Sendable` by default. No actor annotation required in Phase 1.

**Logging convention:** No `print()` statements — use `os.log` if any logging is added. This file has no logging in Phase 1.

---

### `Resources/Info.plist` (config)

**Source:** RESEARCH.md Code Examples + CLAUDE.md project.yml skeleton

**Note:** xcodegen can generate Info.plist from `info.properties` in project.yml (Pattern 1 above). If xcodegen generates it, do NOT create a hand-written Info.plist at the same path — it will conflict. Check which approach is used; if xcodegen writes to `Resources/Info.plist`, the planner should treat this file as xcodegen-managed.

**Key properties:**
```xml
<key>LSUIElement</key>
<true/>
<key>CFBundleIdentifier</key>
<string>dev.chutipon.chordtyper</string>
<key>NSAccessibilityUsageDescription</key>
<string>ChordTyper needs Accessibility access to intercept keystrokes for chord detection.</string>
```

**SCAF-04 requirement:** `LSUIElement` must be boolean `true` — use `<true/>` in XML, `true` (not `"YES"`) in YAML.

---

### `Resources/ChordTyper.entitlements` (config)

**Source:** RESEARCH.md Pattern 3 + CONTEXT.md SCAF-05

**Full pattern** (from RESEARCH.md Pattern 3):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.temporary-exception.accessibility</key>
    <true/>
</dict>
</plist>
```

**What NOT to include:**
- `com.apple.security.app-sandbox` — CLAUDE.md explicitly forbids; blocks CGEventPost
- Any other entitlement keys — minimal is correct for ad-hoc personal distribution

---

### `Resources/dictionaries/.gitkeep` (placeholder)

**Source:** RESEARCH.md recommended project structure

No code pattern — empty file. Purpose: ensures the `dictionaries/` directory is tracked by git. xcodegen `resources` path references this directory for future Phase 4–5 JSON files.

---

### `Tests/ChordTyperTests/ChordTyperSmokeTests.swift` (test)

**Source:** RESEARCH.md Pattern 5 + decisions D-04/D-09

**Constraint:** D-04 — single smoke test class, one test method only. No logic tested in Phase 1.

**Pattern** (simplified form from RESEARCH.md — avoids bundle ID assertion complexity):
```swift
// Tests/ChordTyperTests/ChordTyperSmokeTests.swift
import XCTest

final class ChordTyperSmokeTests: XCTestCase {
    func testSmoke_testPipelineExecutes() {
        XCTAssert(true, "Test pipeline is functional")
    }
}
```

**Naming convention** (from CLAUDE.md testing conventions):
- Class: `[Component]Tests` → `ChordTyperSmokeTests`
- Method: `test[Component]_[scenario]_[expectedBehavior]` → `testSmoke_testPipelineExecutes`

**Bundle ID assertion option** (D-09): If the planner wants to assert the bundle identifier, use `Bundle(for: ChordTyperSmokeTests.self).bundleIdentifier` (returns the test bundle ID `"dev.chutipon.chordtypertests"`), not `Bundle.main.bundleIdentifier` (returns the XCTest runner ID). The simpler `XCTAssert(true)` form is preferred for a pure smoke test.

---

## Shared Patterns

### Swift 6 Strict Concurrency
**Source:** CLAUDE.md Coding Conventions + decisions D-06/D-07
**Apply to:** All `.swift` files in this phase and all future phases
- Use actors to isolate mutable state
- No `@unchecked Sendable` workarounds
- CGEventTap callback (future phases) must dispatch heavy work to a background queue
- `SWIFT_VERSION: "6"` in project.yml enforces this at compile time

### Logging Convention
**Source:** CLAUDE.md Coding Conventions
**Apply to:** All `.swift` files
```swift
import os.log
private let logger = Logger(subsystem: "dev.chutipon.chordtyper", category: "ComponentName")
// Use: logger.info("message")  logger.error("message")
// Never: print("message")
```
Phase 1 files have no logging calls, but this convention applies from Phase 2 onward.

### No Force Unwraps
**Source:** CLAUDE.md Coding Conventions
**Apply to:** All `.swift` files
```swift
// Never: let value = optional!
// Always: guard let value = optional else { return }
// Or: let value = optional ?? defaultValue
```

### Bundle Identifier Pattern
**Source:** Decision D-08/D-09 + CLAUDE.md
**Apply to:** `project.yml`, `Info.plist`, `ChordTyper.entitlements`, smoke test
- App bundle ID: `dev.chutipon.chordtyper`
- Test bundle ID: `dev.chutipon.chordtypertests`
- Format: reverse-domain, all lowercase (chutipon.dev → dev.chutipon)

### Ad-hoc Signing Pattern
**Source:** CLAUDE.md Constraints + RESEARCH.md project.yml pattern
**Apply to:** `project.yml`, `Makefile` (codesign call)
```yaml
# project.yml target settings
CODE_SIGN_IDENTITY: "-"
CODE_SIGN_STYLE: Manual
ENABLE_HARDENED_RUNTIME: NO
```
```makefile
# Makefile dmg target
codesign --force --deep -s - "$(APP_PATH)"
```

---

## No Analog Found

All Phase 1 files have no analog — this is a greenfield project. The patterns above are sourced from:

| File | Reason | Pattern Source |
|------|--------|----------------|
| `project.yml` | No existing xcodegen project | RESEARCH.md Pattern 1, CLAUDE.md project.yml skeleton |
| `Makefile` | No existing Makefile | RESEARCH.md Pattern 4, CLAUDE.md Makefile pattern |
| `ChordTyperApp.swift` | No existing Swift source | RESEARCH.md Pattern 2, CLAUDE.md file responsibilities |
| `Info.plist` | No existing app bundle | RESEARCH.md Code Examples, xcodegen-managed via project.yml |
| `ChordTyper.entitlements` | No existing entitlements | RESEARCH.md Pattern 3, SCAF-05 |
| `.gitkeep` | No existing directory structure | RESEARCH.md recommended structure |
| `ChordTyperSmokeTests.swift` | No existing test files | RESEARCH.md Pattern 5, D-04 |

---

## Pre-Flight Checklist for Planner

Before writing any file, the executor must run:
```bash
brew install xcodegen   # xcodegen NOT currently installed (verified: command -v xcodegen → nothing)
xcodegen --version      # confirm 2.45.4
```

After writing `project.yml` and sources:
```bash
xcodegen generate       # verify no xcodeVersion errors
xcodebuild -list        # confirm scheme names before writing Makefile test target
make build              # phase gate 1
make test               # phase gate 2
```

---

## Metadata

**Analog search scope:** Entire project root (`/Users/chutipon/Documents/project/chord-typer/`)
**Files scanned:** 3 (CLAUDE.md, README.md, spec.md — no source files exist)
**Pattern extraction date:** 2026-05-18
**Greenfield:** Yes — all patterns sourced from CLAUDE.md and RESEARCH.md, not existing code
