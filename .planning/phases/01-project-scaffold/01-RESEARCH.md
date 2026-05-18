# Phase 1: Project Scaffold - Research

**Researched:** 2026-05-18
**Domain:** macOS Xcode project scaffold (xcodegen, Makefile, SwiftUI App entry point, entitlements)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Use `@main` App struct (pure SwiftUI entry point) with a minimal `MenuBarExtra` stub — placeholder text only ("ChordTyper is running")
- **D-02:** No `@NSApplicationDelegateAdaptor` in Phase 1 — added in Phase 2 when lifecycle hooks are needed for menubar setup
- **D-03:** No separate `main.swift` file — `@main` attribute on the App struct serves as the entry point
- **D-04:** Single smoke test class (`ChordTyperSmokeTests`) with one test that verifies the test pipeline works
- **D-05:** Each subsequent phase adds its own test files — no pre-created stubs for future phases
- **D-06:** `SWIFT_STRICT_CONCURRENCY=complete` enabled from Phase 1 in project.yml
- **D-07:** Swift 6 strict mode — all files written from this phase onward must be concurrency-safe. No `@unchecked Sendable` workarounds.
- **D-08:** Bundle ID is `dev.chutipon.chordtyper` (reverse-domain of chutipon.dev, all lowercase)
- **D-09:** Used in project.yml `PRODUCT_BUNDLE_IDENTIFIER`, entitlements, and smoke test assertions

### Claude's Discretion

None specified — all decisions locked.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCAF-01 | Project uses xcodegen (project.yml) to generate .xcodeproj from CLI | xcodegen 2.45.4 available via `brew install xcodegen`; project.yml skeleton documented in CLAUDE.md |
| SCAF-02 | Makefile provides build, run, dmg, clean targets | Makefile pattern documented in CLAUDE.md; `make test` target also required per success criteria |
| SCAF-03 | Folder structure matches spec (Sources/, Resources/, dictionaries/) | Greenfield project; no existing structure. Structure defined in spec.md and CLAUDE.md |
| SCAF-04 | Info.plist sets LSUIElement=YES (no Dock icon) | Set via xcodegen `info.properties.LSUIElement: true` in project.yml |
| SCAF-05 | Entitlements file includes accessibility permissions | Entitlements file at `Resources/ChordTyper.entitlements`; key: `com.apple.security.temporary-exception.accessibility` |
</phase_requirements>

---

## Summary

Phase 1 creates the project skeleton from which all subsequent phases build. The scope is strictly files and configuration — no runtime functionality beyond a placeholder menubar stub that allows the app to launch and quit. All 5 requirements are configuration/tooling concerns: xcodegen project.yml, Makefile, folder layout, Info.plist, and entitlements.

The stack is fully defined by CLAUDE.md (xcodegen + xcodebuild + Make). The key risk for this phase is the **version mismatch** between the documented stack (Xcode 16.4 / Swift 6.1) and the actual installed toolchain (Xcode 26.5 / Swift 6.3.2 / macOS SDK 26.5). This requires updating `xcodeVersion` in project.yml and using `SWIFT_VERSION: "6"` rather than `"6.1"`. xcodegen is not currently installed and must be installed as the first task.

The second risk is that `SWIFT_STRICT_CONCURRENCY=complete` (D-06) is a Swift 5.x compatibility setting. In Swift 6 language mode (`SWIFT_VERSION: "6"`), strict concurrency checking is the default — the build setting is not needed and may cause warnings. Both approaches are covered below.

**Primary recommendation:** Install xcodegen via Homebrew, write project.yml targeting `SWIFT_VERSION: "6"` (Swift 6 language mode), set `xcodeVersion` to match the installed Xcode 26 or omit it, write a minimal `ChordTyperApp.swift` with `@main`, and verify with `make build && make test`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Build configuration | Build tooling (xcodegen/Make) | — | project.yml and Makefile are the sole build artifacts |
| App entry point | macOS App process | — | `@main` App struct bootstraps SwiftUI lifecycle |
| Dock icon suppression | macOS system | Build config (Info.plist) | `LSUIElement=YES` in Info.plist; system reads it at launch |
| Accessibility declaration | macOS system | Build config (entitlements) | Entitlements file is the system interface; TCC prompts at runtime |
| Test infrastructure | XCTest framework | Build config (test target in project.yml) | xcodegen generates the test target; xcodebuild runs it |

---

## Standard Stack

### Core (no third-party packages — Apple frameworks only)

| Tool/Technology | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| xcodegen | 2.45.4 | Generate `.xcodeproj` from `project.yml` | Only CLI-buildable way to manage Xcode projects without committing `.xcodeproj`. Constraint in CLAUDE.md. [VERIFIED: brew info xcodegen] |
| Swift | 6 (language mode) / 6.3.2 (toolchain) | Implementation language | Toolchain on this machine is Swift 6.3.2 (Xcode 26.5). Use `SWIFT_VERSION: "6"` for strict concurrency as default. [VERIFIED: swift --version] |
| Xcode | 26.5 (Build version 17F42) | Compiler + xcodebuild | Installed Xcode. macOS SDK 26.5 available. CLAUDE.md references 16.4 — outdated; use 26.5 actual. [VERIFIED: xcodebuild -version] |
| SwiftUI `MenuBarExtra` | macOS 13+ | Placeholder menubar stub | `@main` App struct + `MenuBarExtra` scene. No AppKit needed in Phase 1. [CITED: CLAUDE.md] |
| XCTest | Xcode 26.5 bundled | Smoke test target | Standard Apple unit testing framework. `xctest` binary confirmed at `/Applications/Xcode.app/Contents/Developer/usr/bin/xctest`. [VERIFIED: xcrun --find xctest] |
| GNU Make | 3.81 (system) | Build orchestration | Ships with macOS. Confirmed: `make --version`. [VERIFIED: make --version] |

### No packages to install (Apple frameworks only)

The zero-dependency constraint from CLAUDE.md means no npm/pip/cargo packages. No Package Legitimacy Audit is needed for this phase. xcodegen is a build tool installed via Homebrew, not a library dependency.

---

## Package Legitimacy Audit

No external library packages are installed in this phase. xcodegen is a build tool installed via Homebrew system package manager.

| Tool | Registry | Notes | Disposition |
|------|----------|-------|-------------|
| xcodegen | Homebrew | Formula: `xcodegen`, version 2.45.4, MIT license, official GitHub: github.com/yonaskolb/XcodeGen | Approved |

---

## Architecture Patterns

### System Architecture Diagram

```
Developer invokes CLI
        │
        ▼
  make build
        │
        ├─► xcodegen generate
        │       └─► reads project.yml → writes ChordTyper.xcodeproj
        │
        └─► xcodebuild -scheme ChordTyper -configuration Release build
                └─► compiles Sources/ChordTyper/ChordTyperApp.swift
                        └─► @main App struct → MenuBarExtra stub
                └─► bundles Resources/Info.plist + Resources/ChordTyper.entitlements
                └─► codesign --force --deep -s - (ad-hoc)
                └─► outputs .build/ChordTyper.app

  make test
        │
        └─► xcodebuild -scheme ChordTyperTests test
                └─► runs Tests/ChordTyperTests/ChordTyperSmokeTests.swift
                        └─► one test: verifies test pipeline executes
```

### Recommended Project Structure

```
chord-typer/
├── project.yml                         # xcodegen config — generates .xcodeproj
├── Makefile                            # build, run, test, dmg, clean targets
├── Sources/
│   └── ChordTyper/
│       └── ChordTyperApp.swift         # @main App struct with MenuBarExtra stub
├── Resources/
│   ├── Info.plist                      # LSUIElement=YES, bundle metadata
│   ├── ChordTyper.entitlements         # accessibility permission declaration
│   └── dictionaries/                   # empty dir; placeholder for Phases 4-5
│       └── .gitkeep
└── Tests/
    └── ChordTyperTests/
        └── ChordTyperSmokeTests.swift  # single smoke test: pipeline works
```

Note: `main.swift` is NOT created (D-03). `AppDelegate.swift` is NOT created (D-02). All CLAUDE.md `File Responsibilities` table files beyond `ChordTyperApp.swift` are stubs for future phases.

### Pattern 1: xcodegen project.yml for macOS menubar app

**What:** A `project.yml` that declares the app target with the right Info.plist keys, entitlements, and build settings. xcodegen reads this and writes `ChordTyper.xcodeproj`.

**Critical field: `xcodeVersion`** — CLAUDE.md documents `16.4` but the installed Xcode is `26.5`. xcodegen uses this field to set compatibility warnings; it does NOT block generation. Safest approach: set to `"16.4"` (xcodegen 2.45.4 was validated against Xcode 16.x) or omit the field entirely to skip validation. [ASSUMED — xcodegen changelog not consulted for version 2.45.4 behavior with Xcode 26]

**Critical field: `SWIFT_VERSION`** — Use `"6"` to enable Swift 6 language mode (strict concurrency by default). D-06 specifies `SWIFT_STRICT_CONCURRENCY=complete` — this is the Swift 5 opt-in equivalent. In Swift 6 mode, this setting is redundant but harmless. Include both for explicitness.

**Example project.yml:**
```yaml
name: ChordTyper
options:
  bundleIdPrefix: dev.chutipon
  deploymentTarget:
    macOS: "13.0"
  # xcodeVersion omitted — xcodegen 2.45.4 on Xcode 26 (no validated version string)

settings:
  SWIFT_VERSION: "6"
  SWIFT_STRICT_CONCURRENCY: complete      # D-06: belt-and-suspenders for Swift 5 compat mode
  MACOSX_DEPLOYMENT_TARGET: "13.0"
  ENABLE_HARDENED_RUNTIME: NO             # ad-hoc signing only — no Developer ID

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

### Pattern 2: Minimal @main App struct (Phase 1 stub)

**What:** The entry point for Phase 1 — just enough to compile and show a menubar item.

**Constraint:** D-01 (MenuBarExtra stub only), D-02 (no NSApplicationDelegateAdaptor), D-03 (no main.swift).

```swift
// Sources/ChordTyper/ChordTyperApp.swift
// Source: CLAUDE.md and CONTEXT.md D-01 through D-03
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

**Swift 6 concurrency note:** This struct is `Sendable` by default since it has no stored properties. No actor annotation needed. [CITED: CLAUDE.md — Swift 6 strict concurrency]

### Pattern 3: Entitlements file for CGEventTap (non-sandboxed)

**What:** `Resources/ChordTyper.entitlements` declares accessibility permission intent.

**Why this key:** SCAF-05 and the phase success criteria both specify `com.apple.security.temporary-exception.accessibility`. For a non-sandboxed ad-hoc app, this key is not required by macOS to grant TCC access — access is granted at runtime via System Settings. However, the key is required by the success criteria and signals intent for future distribution. [ASSUMED — Apple does not explicitly document this key's effect on non-sandboxed builds; behavior verified by community sources and ZipChord/alt-tab-macos pattern]

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

### Pattern 4: Makefile with build, run, test, dmg, clean targets

**What:** Makefile wrapping xcodegen + xcodebuild. CLAUDE.md provides the skeleton; adapted for `make test` (required by success criteria item 3).

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

**IMPORTANT: App output path.** The CLAUDE.md skeleton shows `$(BUILD_DIR)/$(SCHEME).app` but the actual xcodebuild derived data layout is `$(BUILD_DIR)/Build/Products/Release/$(SCHEME).app`. Use the full path. [ASSUMED — path depends on xcodebuild version; should be verified on first `make build`]

### Pattern 5: Smoke test class (D-04)

**What:** A single XCTest class that confirms the test target links and executes. No logic tested.

```swift
// Tests/ChordTyperTests/ChordTyperSmokeTests.swift
import XCTest

final class ChordTyperSmokeTests: XCTestCase {
    func testSmoke_testPipelineExecutes() {
        // D-04: Verifies the test pipeline compiles and runs.
        // D-09: Bundle identifier is set to the expected value.
        XCTAssertEqual(Bundle.main.bundleIdentifier, "dev.chutipon.chordtypertests")
    }
}
```

**Note on bundle ID in tests:** `Bundle.main` in an XCTest runner refers to the test runner bundle, not the app bundle. The test bundle ID is `dev.chutipon.chordtypertests` (from project.yml). If D-09 intends to assert the app bundle ID from the test, use `Bundle(identifier: "dev.chutipon.chordtyper")` instead — but this requires the app to be linked. A simpler smoke test just passes unconditionally:

```swift
func testSmoke_testPipelineExecutes() {
    XCTAssert(true, "Test pipeline is functional")
}
```

### Anti-Patterns to Avoid

- **Including main.swift:** Causes "expressions are not allowed at the top level" or duplicate `@main` entry point conflict. D-03 forbids it.
- **Setting `APP_SANDBOX_ENTITLEMENTS`:** Sandboxing blocks CGEventPost. CLAUDE.md explicitly forbids the App Sandbox entitlement.
- **Using `ENABLE_HARDENED_RUNTIME: YES`:** Incompatible with ad-hoc signing for personal use; causes CGEventPost to fail at runtime.
- **Wrong `xcodeVersion` string:** If xcodegen rejects the version string for Xcode 26, omit the `xcodeVersion` field rather than setting an incorrect value.
- **Wrong .app output path in Makefile:** The `CLAUDE.md` skeleton uses `$(BUILD_DIR)/$(SCHEME).app` which is not the actual derivedData output path. Use `$(BUILD_DIR)/Build/Products/Release/$(SCHEME).app`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Xcode project file | Manual `.pbxproj` editing | `xcodegen` with `project.yml` | `.pbxproj` is a binary-ish format with merge conflict risk; xcodegen is the project constraint |
| Build script | Shell script calling `swiftc` directly | `xcodebuild` via Makefile | `swiftc` cannot handle Info.plist embedding, entitlements signing, or app bundle structure |
| Info.plist embedding | Custom plist generation script | xcodegen `info.properties` | xcodegen handles the Info.plist merge correctly including all required keys |

---

## Common Pitfalls

### Pitfall 1: xcodegen not installed
**What goes wrong:** `make build` fails immediately with `xcodegen: command not found`.
**Why it happens:** xcodegen is not pre-installed — it must be explicitly installed via Homebrew. It is not present on this machine (verified: `command -v xcodegen` returns nothing).
**How to avoid:** First task in Wave 1 must be `brew install xcodegen`. Verify with `xcodegen --version`.
**Warning signs:** `make generate` step fails with "command not found".

### Pitfall 2: xcodeVersion mismatch
**What goes wrong:** xcodegen may warn or error that `xcodeVersion: "16.4"` does not match the installed Xcode 26.5.
**Why it happens:** The CLAUDE.md skeleton was written for Xcode 16.4; the machine runs Xcode 26.5.
**How to avoid:** Either omit `xcodeVersion` from project.yml entirely (xcodegen skips version validation), or set it to a value xcodegen 2.45.4 accepts for Xcode 26. If xcodegen errors, remove the `xcodeVersion` field.
**Warning signs:** `xcodegen generate` exits with a version-mismatch error.

### Pitfall 3: Wrong .app output path in Makefile
**What goes wrong:** `make run` calls `open` on a path that does not exist; `make dmg` fails codesigning a missing file.
**Why it happens:** xcodebuild puts the built product at `$(BUILD_DIR)/Build/Products/Release/ChordTyper.app`, not `$(BUILD_DIR)/ChordTyper.app` as the CLAUDE.md skeleton implies.
**How to avoid:** Use `$(BUILD_DIR)/Build/Products/Release/$(SCHEME).app` for APP_PATH. Alternatively query xcodebuild: `xcodebuild -showBuildSettings ... | grep BUILT_PRODUCTS_DIR`.
**Warning signs:** `open .build/ChordTyper.app` → "file not found".

### Pitfall 4: SWIFT_VERSION and SWIFT_STRICT_CONCURRENCY interaction
**What goes wrong:** With `SWIFT_VERSION: "6"`, strict concurrency is already the default. Setting `SWIFT_STRICT_CONCURRENCY: complete` is a no-op (Swift 5 setting) and may produce a deprecation warning in Xcode 26.
**Why it happens:** `SWIFT_STRICT_CONCURRENCY` was introduced as an opt-in for Swift 5.7-5.9. In Swift 6 language mode, the concept is replaced by the language mode itself.
**How to avoid:** Include `SWIFT_STRICT_CONCURRENCY: complete` per D-06 (it is harmless in Swift 6 mode, and the planner/checker will want to see the decision honored). No action needed if a warning appears — it does not break the build.
**Warning signs:** Build succeeds but shows "SWIFT_STRICT_CONCURRENCY is not valid with Swift 6 language mode".

### Pitfall 5: Duplicate @main / entry point conflict
**What goes wrong:** Adding `main.swift` to the project causes a Swift compiler error: "expressions are not allowed at the top level" or duplicate entry point.
**Why it happens:** Swift allows either `@main` attribute OR a `main.swift` top-level file, not both.
**How to avoid:** D-03 explicitly forbids `main.swift`. Verify project.yml `sources` path does not accidentally include a `main.swift` if one is accidentally created.

---

## Code Examples

### project.yml Info.plist properties for LSUIElement (SCAF-04)
```yaml
# Source: CLAUDE.md — project.yml skeleton
info:
  path: Resources/Info.plist
  properties:
    LSUIElement: true    # Hides Dock icon — set to boolean true, not string "YES"
```

### Entitlements file (SCAF-05)
```xml
<!-- Source: CONTEXT.md success criteria, CLAUDE.md -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.temporary-exception.accessibility</key>
    <true/>
</dict>
</plist>
```

### Makefile test target
```makefile
# Source: CLAUDE.md Makefile pattern + phase success criteria item 3
test: generate
	xcodebuild -scheme ChordTyperTests -configuration Debug \
	  -derivedDataPath $(BUILD_DIR) test
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `xcodeVersion: "16.4"` in project.yml | Xcode 26.5 is installed; `xcodeVersion` may need updating or omission | May 2026 (Xcode 26 release) | xcodegen xcodeVersion field should match or be omitted |
| `SWIFT_VERSION: "6.1"` (toolchain version) | Use `SWIFT_VERSION: "6"` (language mode) | Xcode 16+ / Swift 6 | Toolchain is 6.3.2 but language mode is declared as "6" |
| `SWIFT_STRICT_CONCURRENCY: complete` | Redundant in Swift 6 language mode | Swift 6.0 language mode | Still harmless; include per D-06 |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | xcodegen 2.45.4 generates a valid .xcodeproj when run against Xcode 26.5 without `xcodeVersion` set | Pitfalls #2, project.yml pattern | xcodegen may fail; mitigation: install and test immediately |
| A2 | The built .app is located at `$(BUILD_DIR)/Build/Products/Release/ChordTyper.app` with `-derivedDataPath $(BUILD_DIR)` | Makefile Pattern #4, Pitfall #3 | Makefile `run` and `dmg` targets reference wrong path; fix by querying BUILT_PRODUCTS_DIR |
| A3 | `com.apple.security.temporary-exception.accessibility` in entitlements is harmless for non-sandboxed ad-hoc builds and satisfies SCAF-05 success criteria | Pattern #3 (entitlements) | If Apple rejects this key for non-sandboxed apps, xcodebuild codesign step may warn; the key is unlikely to cause a build failure |
| A4 | `xcodeVersion` field can be omitted from project.yml without causing xcodegen errors | Pattern #1 (project.yml) | If xcodegen requires xcodeVersion, use "16.4" and ignore the mismatch warning |

---

## Open Questions

1. **Does xcodegen 2.45.4 support Xcode 26 / macOS 26 SDK?**
   - What we know: xcodegen Homebrew formula requires Xcode >= 15.3. Xcode 26.5 is installed.
   - What's unclear: Whether xcodegen 2.45.4 was released before or after Xcode 26 and whether it handles the new xcodeVersion string.
   - Recommendation: Install xcodegen and run `xcodegen generate` immediately as the first verification. If it fails, omit `xcodeVersion` from project.yml.

2. **Exact xcodebuild scheme name for the test target**
   - What we know: xcodegen generates a scheme per target. The test target is named `ChordTyperTests` in project.yml.
   - What's unclear: Whether xcodebuild sees a scheme named `ChordTyperTests` or `ChordTyper` with a test action.
   - Recommendation: After `xcodegen generate`, run `xcodebuild -list` to see generated scheme names and adjust the Makefile `test` target accordingly.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| xcodebuild | SCAF-01, SCAF-02 | Yes | Xcode 26.5 (Build 17F42) | — |
| Swift toolchain | SCAF-01 | Yes | 6.3.2 (swiftlang-6.3.2.1.108) | — |
| GNU Make | SCAF-02 | Yes | 3.81 | — |
| xcodegen | SCAF-01 | **No** | Not installed | `brew install xcodegen` (Homebrew 5.1.10 available) |
| Homebrew | xcodegen install | Yes | 5.1.10 | — |
| codesign | SCAF-02 (dmg target) | Yes | System (Xcode CLI tools) | — |
| hdiutil | SCAF-02 (dmg target) | Yes | System (macOS) | — |

**Missing dependencies with no fallback:**
- None — all missing tools have install paths available.

**Missing dependencies with fallback:**
- `xcodegen`: Not installed. Install with `brew install xcodegen`. This is the first task of Wave 1.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode 26.5 bundled) |
| Config file | project.yml test target (`ChordTyperTests`) |
| Quick run command | `make test` |
| Full suite command | `make test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SCAF-01 | `xcodegen generate` produces valid .xcodeproj | smoke/manual | `xcodegen generate && echo OK` | ❌ Wave 0 (no test file; verified by make build success) |
| SCAF-02 | `make build` compiles successfully | smoke/manual | `make build` | ❌ Wave 0 (build success is the test) |
| SCAF-03 | Folder structure matches spec | manual | `ls Sources/ChordTyper Resources Tests/ChordTyperTests` | ❌ Wave 0 |
| SCAF-04 | LSUIElement=YES, no Dock icon | manual | Launch app, verify no Dock icon | ❌ Phase gate only |
| SCAF-05 | Entitlements declare accessibility | manual | `cat Resources/ChordTyper.entitlements` | ❌ Wave 0 |
| D-04 | Smoke test passes | unit | `make test` | ❌ Wave 0 — `Tests/ChordTyperTests/ChordTyperSmokeTests.swift` |

### Sampling Rate

- **Per task commit:** `make build` (confirms project compiles)
- **Per wave merge:** `make build && make test`
- **Phase gate:** `make build && make test` both green, manual Dock-icon check

### Wave 0 Gaps

- [ ] `Tests/ChordTyperTests/ChordTyperSmokeTests.swift` — single smoke test (REQ D-04)
- [ ] `Sources/ChordTyper/ChordTyperApp.swift` — `@main` entry point (needed for build to succeed)
- [ ] `project.yml` — xcodegen config (Wave 0 must create this before any `make` target works)
- [ ] `Makefile` — build orchestration
- [ ] `Resources/Info.plist`, `Resources/ChordTyper.entitlements` — bundle metadata
- [ ] xcodegen install: `brew install xcodegen`

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — |
| V3 Session Management | No | — |
| V4 Access Control | No | — |
| V5 Input Validation | No | No user input in scaffold phase |
| V6 Cryptography | No | — |

**Security note for this phase:** The entitlements file explicitly omits `com.apple.security.app-sandbox` (per CLAUDE.md "What NOT to Use"). This is correct — sandboxing would block CGEventPost in future phases. The only security-relevant decision is ad-hoc signing (`CODE_SIGN_IDENTITY: "-"`), which is correct for personal use per DIST-01.

---

## Sources

### Primary (HIGH confidence)
- CLAUDE.md — project.yml skeleton, Makefile pattern, file responsibilities, build commands — project source of truth
- `xcodebuild -version` (this machine) — Xcode 26.5, Build 17F42
- `swift --version` (this machine) — Swift 6.3.2
- `make --version` (this machine) — GNU Make 3.81
- `xcrun --find xctest` — XCTest at `/Applications/Xcode.app/Contents/Developer/usr/bin/xctest`
- `brew info xcodegen` — version 2.45.4, MIT, requires Xcode >= 15.3

### Secondary (MEDIUM confidence)
- CONTEXT.md D-01 through D-09 — locked implementation decisions
- spec.md §Project Structure — folder layout
- .planning/REQUIREMENTS.md §Scaffold — SCAF-01 through SCAF-05

### Tertiary (LOW confidence, marked ASSUMED)
- xcodegen 2.45.4 behavior with Xcode 26 xcodeVersion field — A1
- xcodebuild derived data .app output path — A2

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools verified on this machine
- Architecture: HIGH — greenfield; no existing code conflicts
- Pitfalls: HIGH — version mismatch discovered via direct tool queries; path assumptions flagged
- Test infrastructure: HIGH — XCTest confirmed available

**Research date:** 2026-05-18
**Valid until:** 2026-06-18 (stable tooling; xcodegen version pinned)
