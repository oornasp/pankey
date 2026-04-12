# Phase 1: Pankey macOS IME Scaffold Complete

**Date**: 2026-04-11 10:28
**Severity**: Low (foundational work)
**Component**: Project structure, build system
**Status**: Resolved

## What Happened

Scaffolded Pankey — a native macOS Vietnamese Input Method Editor. Created Swift Package (5.9+), Xcode project with proper IME registration plumbing, and clean build pipeline.

## Technical Wins

- **PankeyCore Swift Package**: `swift build` passes cleanly on Swift 6.3 (macOS 13.0+ target)
- **IME Registration**: Info.plist includes full TSMPlugin bundle config + InputMethodServerModeEnabled
- **Build Chain**: XCLocalSwiftPackageReference correctly resolves local package; debug builds use ad-hoc signing (no cert friction)
- **Git Hygiene**: Replaced garbage .gitignore with Swift/macOS-specific rules; committed clean (4b62068)

## The Non-Obvious Decision: No Sandbox Entitlements

Sandboxing breaks IMKServer communication — silent failure. Entitlements file is intentionally empty with comments explaining why. Future dev won't waste hours chasing phantom networking issues.

## External Blocker

PressStart2P-Regular.ttf font (OFL 1.1, fonts.google.com) — Phase 5 blocker. Add to `.gitignore` once downloaded.

## Lessons

- IME sandbox incompatibility is undocumented misery; document explicitly or lose days.
- XCLocalSwiftPackageReference requires exact path — no symlink resolution.
- Don't overthink entitlements until you hit the actual sandbox boundary.

## Next: Phase 2

Implement IMKInputController subclass + key event pipeline (backspace, tone marks).

---

**Commit**: feat: scaffold Pankey macOS Vietnamese IME project (4b62068)
