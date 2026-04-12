# Phase 5: Menu Bar, Settings UI, and PixelUI Design System

**Date**: 2026-04-12
**Severity**: Medium
**Component**: Menu bar controller, Settings window, UI framework
**Status**: Resolved

## What Happened

Implemented full menu bar integration with pixel-themed Settings window. Added NSStatusItem with dynamic "VI"/"EN" icon, dropdown menu (Toggle/Telex-VNI/Settings/Quit), and multi-tab settings panel with hotkey recorder and app exclusion list.

## The Brutal Truth

This phase was clean execution—no major fires. The PixelUI design system emerged naturally from requirements rather than being ripped out and rebuilt. One legitimate oversight from Phase 4 surfaced: `AppExclusionManager.swift` existed on disk but was absent from `project.pbxproj`, which would have broken the build silently. Caught and fixed before it became a problem.

## Technical Details

**New Components:**
- `MenuBarController.swift`: NSStatusItem observing `UserDefaults.didChangeNotification` for icon sync. Dropdown menu triggers both app-level toggles and settings window.
- `SettingsWindowController.swift`: NSPanel (420×340) wrapping SwiftUI. Set `isReleasedWhenClosed=false` to preserve window state.
- `PixelUI/*`: Pixel theme palette (#1a1a2e dark, #00ff9f neon), Press Start 2P font helper, button/toggle/border modifiers.
- `GeneralSettingsView.swift`: VI/EN toggle (@AppStorage), Telex/VNI picker, hotkey recorder using NSEvent local monitor.

**Critical Ordering Fix:**
InputController hotkey check now runs *before* the modifier-passthrough guard. This allows Ctrl+Space to trigger hotkey handler even when control key would normally fall through. Proper precedence prevents modifier keys from being consumed prematurely.

## What Worked Well

- HotkeyStore kept embedded in GeneralSettingsView (not a separate file)—stayed under 200 LOC without sacrificing clarity.
- UserDefaults KVO binding between menu bar icon and settings toggle eliminated sync bugs.
- Exclusion list implementation straightforward: scrollable bundle ID list with Add/Remove buttons.

## Lessons Learned

1. **Build file consistency**: File existence on disk ≠ inclusion in build. `pbxproj` must be explicit. Always verify new files are registered.
2. **Guard ordering matters**: Event handlers need proper precedence. Modifiers should not be consumed before hotkey dispatch can evaluate them.
3. **KVO over polling**: UserDefaults notification observer is more elegant than timer-based checks for UI sync.

## Next Steps

Phase 6: Convert Tool UI stub → implement Vietnamese composition converter (noun+verb combinations). Requires PankeyCore dictionary interface.

**Owner**: Implementation team
**Timeline**: Estimate 1 week (depends on dictionary API finalization)

