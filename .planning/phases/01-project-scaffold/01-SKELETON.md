# Walking Skeleton -- ChordTyper

**Phase:** 1
**Generated:** 2026-05-18

## Capability Proven End-to-End

The app builds from CLI via `make build`, launches as a menubar-only item (no Dock icon), displays "ChordTyper is running" in the dropdown, and quits via the menu. `make test` runs a passing XCTest smoke test.

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Language | Swift 6 (language mode) / Swift 6.3.2 toolchain | Apple-first; strict concurrency catches data races at compile time -- critical for CGEventTap callbacks on background threads |
| UI framework | SwiftUI 5 with `MenuBarExtra` | macOS 13+ native menubar API; no AppKit `NSStatusItem` boilerplate |
| Entry point | `@main` App struct (no main.swift, no AppDelegate) | Pure SwiftUI lifecycle; AppDelegate added in Phase 2 when needed |
| Build system | xcodegen 2.45.4 + GNU Make 3.81 + xcodebuild (Xcode 26.5) | CLI-buildable without Xcode GUI; project.yml is the single source of truth for build config |
| Signing | Ad-hoc (`CODE_SIGN_IDENTITY: "-"`) | Personal use only; no Apple Developer account required |
| Deployment target | macOS 13.0 Ventura+ | `MenuBarExtra` requires macOS 13; Apple Silicon + Intel supported |
| Bundle ID | `dev.chutipon.chordtyper` | Reverse-domain of chutipon.dev, all lowercase |
| Directory layout | `Sources/ChordTyper/`, `Resources/`, `Tests/ChordTyperTests/` | Standard Xcode layout; xcodegen maps these via project.yml |
| Test framework | XCTest (Xcode-bundled) | Apple standard; no third-party test frameworks |
| Concurrency | Swift 6 strict mode + `SWIFT_STRICT_CONCURRENCY=complete` | Belt-and-suspenders; strict concurrency is default in Swift 6 language mode but setting included per D-06 |

## Stack Touched in Phase 1

- [x] Project scaffold (xcodegen project.yml, Makefile, folder structure)
- [x] Routing -- one real scene: `MenuBarExtra` with placeholder text and Quit button
- [ ] Database -- N/A (no database in this project)
- [x] UI -- `MenuBarExtra` dropdown with "ChordTyper is running" text and Quit action
- [x] Build + run verification -- `make build && make run` launches the menubar app; `make test` passes

## Out of Scope (Deferred to Later Slices)

- AppDelegate / NSApplicationDelegateAdaptor (Phase 2)
- CGEventTap keystroke interception (Phase 3)
- Chord detection logic (Phase 4)
- Dictionary loading (Phase 5)
- Text output / key suppression (Phase 6)
- Global toggle shortcut (Phase 7)
- Settings window (Phase 8)
- App blacklist/whitelist (Phase 9)
- DMG packaging, permission UX, secure input detection (Phase 10)

## Subsequent Slice Plan

Each later phase adds one vertical slice on top of this skeleton without altering its architectural decisions:

- Phase 2: Menubar skeleton -- icon, dropdown menu with toggle/settings/quit, active/paused visual states
- Phase 3: CGEventTap -- keystroke interception at driver level, accessibility permission check
- Phase 4: Chord detection -- timing window, key collection, sorted-key lookup state machine
- Phase 5: Dictionary system -- JSON loading, hot-reload, English + Thai word sets
- Phase 6: Text output -- key suppression, word posting, smart space
- Phase 7: Global toggle -- Cmd+Shift+Space shortcut, menubar click toggle
- Phase 8: Settings window -- timing slider, dictionary toggles, app filter UI
- Phase 9: App filter -- blacklist/whitelist per-app gating
- Phase 10: Polish + packaging -- secure input detection, DMG, permission UX
