---
phase: 03-cgeventtap
plan: 02
subsystem: event-tap
tags: [verification, permission-ux, pass-through]
dependency_graph:
  requires: [03-01]
  provides: [verified-event-tap, verified-permission-ux]
  affects: [EventTapManager.swift, AppDelegate.swift]
tech_stack:
  added: [ApplicationServices/AXIsProcessTrusted]
  patterns: [dual-permission-check]
key_files:
  modified:
    - Sources/ChordTyper/EventTapManager.swift
    - Sources/ChordTyper/AppDelegate.swift
decisions:
  - "Permission checker uses CGPreflightListenEventAccess() || AXIsProcessTrusted() — Pitfall 1 confirmed: .defaultTap requires Accessibility, not Input Monitoring"
  - "Key lifecycle logs upgraded from .info to .notice for log show persistence — .info is not persisted by macOS unified logging"
metrics:
  duration: ~15 min
  completed: 2026-05-22
---

# Phase 03 Plan 02: Human Verification of CGEventTap Integration

## What Was Verified

Human verification of the CGEventTap transparent pass-through and permission UX flow.

## Verification Results

### Permission Flow
- App launches and correctly detects no Accessibility permission
- NSAlert appears with "Open System Settings" button
- System Settings opens to Privacy & Security > Accessibility
- User must manually add ChordTyper via the "+" button (expected macOS behavior)
- Permission polling (every 2s) detects the grant via `AXIsProcessTrusted()`
- Tap auto-creates within seconds of permission being granted

### Transparent Pass-Through
- Keystrokes pass through unchanged in all tested apps
- No characters missing, duplicated, or delayed
- App quits cleanly from menubar

### Console.app Verification
- "CGEventTap installed and running" log confirmed
- "Permission granted during polling — creating tap" log confirmed
- No error or warning messages during normal operation

## Issues Found and Fixed

### Issue 1: Permission API Mismatch (Pitfall 1)
- **Problem:** `CGPreflightListenEventAccess()` checks Input Monitoring privilege, but `.defaultTap` at `.cgSessionEventTap` requires Accessibility privilege (checked by `AXIsProcessTrusted()`)
- **Symptom:** Permission polling never detected the grant despite user toggling Accessibility ON
- **Fix:** Changed `permissionChecker` to `CGPreflightListenEventAccess() || AXIsProcessTrusted()`
- **Commit:** d7c7259

### Issue 2: Log Visibility
- **Problem:** `os.Logger` at `.info` level is not persisted by macOS unified logging — invisible in `log show`
- **Fix:** Upgraded key lifecycle messages to `.notice` level (persisted by default)

## Commits

- d7c7259: fix(03-02): use AXIsProcessTrusted fallback for permission check and upgrade lifecycle logs to .notice
