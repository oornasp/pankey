---
title: "Pankey Vietnamese IME for macOS"
description: "Native macOS Vietnamese input method with Telex/VNI, per-app exclusion, 8-bit pixel UI"
status: in-progress
priority: P1
effort: 40h
branch: main
tags: [feature, macos, swift, swiftui, ime]
blockedBy: []
blocks: []
created: 2026-04-11
---

# Pankey Vietnamese IME for macOS

## Overview

Build a native macOS Vietnamese IME (Input Method Editor) combining the best of EVKeys (per-app exclusion) and OpenKey (stability on modern macOS), with a novel 8-bit pixel retro UI. Pure Swift/SwiftUI, MIT license, .dmg distribution.

**Key decisions:** Pure Swift (no C++/ObjC++), InputMethodKit framework, NFC Unicode, 8-bit pixel aesthetic via SwiftUI custom styles.

**Research refs:**
- [IMK Swift Research](../reports/researcher-260411-1739-imk-swift-research.md)
- [Vietnamese Composition Algorithm](../reports/researcher-260411-1739-vietnamese-ime-composition-algorithm.md)
- [Brainstorm Report](../reports/brainstorm-260411-1655-pankey-vietnamese-ime.md)

## Phases

| Phase | Name | Status |
|-------|------|--------|
| 1 | [Project Setup & Xcode Config](./phase-01-project-setup-xcode-config.md) | Complete |
| 2 | [PankeyCore Vietnamese Engine](./phase-02-pankeycore-vietnamese-engine.md) | Complete |
| 3 | [IMK Integration](./phase-03-imk-integration.md) | Complete |
| 4 | [App Exclusion Feature](./phase-04-app-exclusion-feature.md) | Complete |
| 5 | [Menu Bar & Settings UI](./phase-05-menu-bar-settings-ui.md) | Complete |
| 6 | [Text Conversion Tool](./phase-06-text-conversion-tool.md) | Complete |
| 7 | [Unit & Integration Tests](./phase-07-unit-integration-tests.md) | Complete |
| 8 | [Distribution & Release](./phase-08-distribution-release.md) | Deferred (no Developer ID cert yet) |

## Dependencies

- Apple InputMethodKit framework (macOS 13.0+)
- No third-party Swift packages required for core
- Press Start 2P font (OFL license, bundled)
- Developer ID certificate for notarization (**Phase 8 deferred until cert available**)

---

## Validation Log

### Session 1 — 2026-04-11
**Trigger:** Post-plan validation interview (hard mode)
**Questions asked:** 6

#### Questions & Answers

1. **[Architecture]** Uppercase/Caps Lock Vietnamese output — Shift+key or Caps Lock
   - Options: Full uppercase support | Shift=passthrough | Defer to v2
   - **Answer:** Yes — full uppercase support
   - **Rationale:** Needed for typing Vietnamese names, headings; Shift detection available in NSEvent.modifierFlags

2. **[Architecture]** Live Settings sync when user switches Telex↔VNI
   - Options: Observe UserDefaults KVO/NotificationCenter | Restart required
   - **Answer:** Observe UserDefaults via KVO/NotificationCenter
   - **Rationale:** Instant effect without IME restart; cleaner UX

3. **[Scope]** False-positive prevention strategy for English text in Telex mode
   - Options: Hybrid vowel-boundary + end-consonant | Minimal commit-on-space | Full phonotactic inventory
   - **Answer:** Hybrid (as planned)
   - **Rationale:** Best balance — prevents most false positives without 50KB data file

4. **[Assumptions]** Apple Developer ID certificate availability
   - Options: Have it | Plan for later | Skip Phase 8
   - **Answer:** Skip Phase 8 entirely for now
   - **Rationale:** No cert yet; phases 1–7 fully buildable without it; Phase 8 deferred

5. **[Architecture]** Keyboard shortcut to toggle VI/EN mode
   - Options: Add hotkey (Recommended) | Menu bar only
   - **Answer:** Yes — add hotkey (default: Ctrl+Space, user-configurable)
   - **Rationale:** Consistent with EVKeys/OpenKey behavior; essential UX for power users

6. **[Scope]** Backspace on committed text: undo full syllable vs standard delete
   - Options: Standard backspace only | Undo last syllable
   - **Answer:** Standard backspace only
   - **Rationale:** Simpler, predictable behavior; syllable-undo is complex and rarely needed

#### Confirmed Decisions
- **Uppercase**: full support via `isUppercase` flag in VietEngine — Phase 2 + 3
- **Settings sync**: UserDefaults observation in InputController — Phase 3
- **False positives**: hybrid strategy as originally planned — no change
- **Phase 8**: deferred — no Developer ID cert; build scripts written but not run
- **Hotkey**: Ctrl+Space default, configurable in Settings — Phase 5 updated
- **Backspace**: standard only — no syllable-undo complexity

#### Action Items
- [x] Phase 2: Add `isUppercase` parameter to VietEngine.handleKey
- [x] Phase 3: Add uppercase detection + UserDefaults observation
- [x] Phase 5: Add hotkey recorder to GeneralSettingsView
- [x] plan.md: Mark Phase 8 as Deferred
