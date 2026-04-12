# 2026-04-11 — Pankey Vietnamese IME: Planning Session

## What happened

Ran full brainstorm + hard-mode planning session for Pankey — a native macOS Vietnamese Input Method Editor (IME) in pure Swift/SwiftUI.

## Context

Existing Vietnamese IMEs each have critical gaps:
- **EVKeys**: has per-app exclusion but crashes on macOS Ventura+
- **OpenKey**: stable on modern macOS but missing per-app exclusion

Goal: combine both strengths, add a novel 8-bit pixel retro UI, open source under MIT.

## Key decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Stack | Pure Swift + SwiftUI | No C++/ObjC++ bridging; user preference |
| IMK | InputMethodKit (native) | Only framework for macOS IME |
| Engine | PankeyCore Swift Package | Modular, testable in isolation |
| Unicode | NFC precomposed | macOS expects precomposed chars |
| UI aesthetic | 8-bit pixel / Press Start 2P font | Differentiator; never seen in this category |
| Distribution | .dmg direct (not App Store) | IMEs cannot be sandboxed |
| Phase 8 | **Deferred** | No Developer ID cert yet |

## Architecture

```
PankeyCore/   ← platform-agnostic Swift Package
PankeyMac/    ← macOS IME .app target
  InputController (IMKInputController subclass)
  AppExclusionManager (per-app bundle ID exclusion)
  MenuBarController (VI/EN status item)
  Settings/ (SwiftUI 8-bit UI — 3 tabs)
```

## Plan created

8 phases, ~40h estimated:
1. Xcode setup + Info.plist IME registration
2. Vietnamese composition engine (CharacterTable, TelexProcessor, VNIProcessor, VietEngine state machine)
3. IMK integration (AppDelegate, InputController, key pipeline)
4. Per-app exclusion (AppExclusionManager + UserDefaults)
5. Menu bar + 8-bit Settings UI (PixelUI design system)
6. Text conversion tool (Telex↔VNI↔Unicode)
7. Unit & integration tests (XCTest, 0 failures required)
8. Distribution (deferred — needs Developer ID)

## Validation gaps surfaced

Three gaps found in post-plan validation interview:

1. **Uppercase support** — plan missed Shift/Caps Lock Vietnamese output (e.g. "TÔI" not just "tôi"). Fixed: `VietEngine.handleKey(_:isUppercase:)` added to Phase 2 + 3.

2. **Live settings sync** — InputController held a VietEngine at startup with no way to pick up Telex↔VNI switch from Settings. Fixed: UserDefaults KVO observation added to Phase 3.

3. **VI/EN toggle hotkey** — no keyboard shortcut planned. Fixed: Ctrl+Space default, user-configurable, added to Phase 5 Settings UI.

## Research artifacts

- `plans/reports/researcher-260411-1739-imk-swift-research.md` — complete IMK/Swift guide
- `plans/reports/researcher-260411-1739-vietnamese-ime-composition-algorithm.md` — full Telex/VNI rules, tone placement, Unicode tables
- `plans/reports/brainstorm-260411-1655-pankey-vietnamese-ime.md` — architecture decision record

## Next

Run `/ck:cook /Users/petereai/Desktop/projects/petereaI/pankey/plans/260411-1742-pankey-vietnamese-ime/plan.md` to begin implementation.
