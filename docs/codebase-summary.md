# Codebase Summary — Pankey Vietnamese IME

**Last updated:** 2026-04-12 | **Phase:** 6 (Text Conversion Tool Complete)

---

## Project Overview

Pankey is a native macOS Vietnamese input method editor (IME) supporting Telex and VNI input methods, with planned per-app exclusion, menu bar settings, and 8-bit pixel retro UI.

---

## Architecture Overview

```
Pankey/
├── PankeyCore/           # Swift Package — Vietnamese composition engine
│   └── Sources/PankeyCore/
│       ├── VietEngine.swift        # Main composition state machine
│       ├── TelesEngine.swift       # Telex-specific phonotactic rules
│       └── VniEngine.swift         # VNI-specific phonotactic rules
├── PankeyMac/            # macOS app — InputMethodKit wrapper
│   ├── AppDelegate.swift           # IMKServer init, MenuBar setup (Phase 5)
│   ├── MenuBarController.swift     # NSStatusItem "VI"/"EN" icon, dropdown menu (Phase 5)
│   ├── InputController.swift       # IMKInputController → VietEngine bridge, hotkey toggle
│   ├── AppExclusionManager.swift   # Per-app exclusion list (Phase 4)
│   ├── Settings/                   # SwiftUI settings panel (Phase 5)
│   │   ├── SettingsWindowController.swift  # NSPanel wrapper
│   │   ├── SettingsView.swift              # Root tabbed container
│   │   ├── GeneralSettingsView.swift       # VI/EN toggle, method picker, hotkey recorder
│   │   ├── ExclusionListView.swift         # Per-app exclusion UI
│   │   ├── ConvertToolView.swift           # Phase 6: full text conversion UI
│   │   └── PixelUI/                        # 8-bit pixel aesthetic components
│   │       ├── PixelTheme.swift            # Color palette, typography, spacing
│   │       ├── PixelButtonStyle.swift      # Primary/secondary/danger button styles
│   │       ├── PixelBorderModifier.swift   # pixelBorder() view modifier
│   │       └── PixelToggleStyle.swift      # Pixel on/off toggle
│   ├── main.swift                  # Manual AppDelegate wiring (no @main)
│   └── Info.plist                  # Input method registration
└── Pankey.xcodeproj/    # Xcode project
```

---

## Component Details

### PankeyCore (Swift Package)

**Purpose:** Pure Swift Vietnamese composition engine and text conversion service, no platform dependencies.

#### VietEngine.swift
- **Responsibilities:**
  - Maintain composition state (decomposed tone marks, base consonants, vowels)
  - Process key input through `.handleKey(String) -> EngineResult`
  - Support `.telex` and `.vni` input methods (switchable via `init(method:)`
  - Detect uppercase via `isUppercase` flag for full Vietnamese uppercase support
  - Expose `currentPreview: String` for pending composition buffer on defocus

- **Public API:**
  ```swift
  class VietEngine {
    init(method: InputMethod)
    func handleKey(_ key: String) -> EngineResult
    func reset()
    var currentPreview: String
  }
  
  enum EngineResult {
    case composing(String)        // Marked text preview
    case commit(String, String?)  // Final text + optional overflow key
    case passthrough              // Let key reach app
  }
  
  enum InputMethod {
    case telex, vni
  }
  ```

- **Key Features:**
  - Hybrid false-positive prevention: vowel boundary + end-consonant checks (Telex)
  - Full uppercase NFC Unicode output (Ả, Ế, Ị, Ỏ, Ủ, Ỳ)
  - Backspace during composition undoes last keystroke
  - Space/punctuation commits with optional overflow handling

#### TelesEngine.swift & VniEngine.swift
- Phonotactic rule sets for Telex vs VNI methods
- Validator methods for valid syllable positions

#### ConversionService.swift (Phase 6)
- **Responsibilities:**
  - Expose `ConversionFormat` public enum: Unicode, Telex, VNI
  - Implement `convert(_:from:to:)` public entry point
  - Implement conversions via word-by-word VietEngine processing:
    - `telexToUnicode`: feed Telex chars through `VietEngine(method: .telex)`, flush at word boundaries
    - `vniToUnicode`: feed VNI chars through `VietEngine(method: .vni)`, flush at word boundaries
    - `unicodeToTelex`: decompose to NFD, reverse-map combining marks to Telex sequences (e.g., ơ→ow, tone marks→f/s/r/x/j)
    - `unicodeToVNI`: placeholder (returns input unchanged, documented stretch goal)
  - Helper `flushEngine(_:word:)`: process word through engine, reset state
  - Helper `telexSequence(for:tone:diacritic:)`: builds Telex key sequence for a character with tone/diacritic

- **Public API:**
  ```swift
  public enum ConversionFormat: String, CaseIterable {
    case unicode = "Unicode"
    case telex   = "Telex"
    case vni     = "VNI"
  }
  
  public struct ConversionService {
    public static func convert(_ text: String, from: ConversionFormat, to: ConversionFormat) -> String
  }
  ```

---

### PankeyMac (macOS Application)

**Purpose:** Wire VietEngine into macOS InputMethodKit, providing system-wide Vietnamese typing.

#### AppDelegate.swift (Updated Phase 5)
- **Responsibilities:**
  - Initialize `IMKServer` with connection name from Info.plist
  - Initialize `MenuBarController` for menu bar UI (Phase 5)
  - Register UserDefaults defaults: `isVietnameseEnabled`, `inputMethod`
  - Wire app-exclusion callback (no-op, for future use)
  - Prevent app termination on last window close (background agent)

- **Key Implementation:**
  ```swift
  @objc class AppDelegate: NSObject, NSApplicationDelegate {
    var server: IMKServer?
    private let menuBarController = MenuBarController()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
      UserDefaults.standard.register(defaults: [
        "isVietnameseEnabled": true,
        "inputMethod": "telex"
      ])
      server = IMKServer(name: connectionName, bundleIdentifier: ...)
      menuBarController.setup()
      AppExclusionManager.shared.onAppChanged = { bundleID in ... }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
      return false  // Keep running when Settings window closes
    }
  }
  ```

#### MenuBarController.swift (NEW — Phase 5)
- **Responsibilities:**
  - Create NSStatusItem in menu bar with pixel-style "VI"/"EN" icon
  - Build dropdown menu: Toggle VI/EN, Method picker (Telex/VNI), Settings, Quit
  - Observe UserDefaults for live icon updates (VI ↔ EN)
  - Open Settings window on "Settings…" action

- **Key Features:**
  - Icon uses Press Start 2P font (8-bit aesthetic) at 9pt
  - Menu items tied to UserDefaults keys (`isVietnameseEnabled`, `inputMethod`)
  - Non-blocking NotificationCenter observer (deregistered on deinit)

- **Public API:**
  ```swift
  final class MenuBarController {
    func setup()  // Called from AppDelegate.applicationDidFinishLaunching
  }
  ```

---

#### AppExclusionManager.swift (Phase 4)
- **Responsibilities:**
  - Maintain exclusion list (`Set<String>`) in UserDefaults key `excludedBundleIDs`
  - Provide O(1) `isCurrentAppExcluded()` check via `NSWorkspace.frontmostApplication`
  - Observe `NSWorkspace.didActivateApplicationNotification` → `onAppChanged` callback
  - Default exclusion list: Terminal, Xcode, VS Code, iTerm2, Sublime, IntelliJ, Kitty
  - Settings UI helpers: `addFrontmostApp()`, `frontmostAppInfo()` for Phase 5

- **Public API:**
  ```swift
  final class AppExclusionManager {
    static let shared: AppExclusionManager
    func isCurrentAppExcluded() -> Bool    // O(1) — called on every key event
    func add(bundleID: String)
    func remove(bundleID: String)
    func excludedBundleIDs() -> [String]
    func addFrontmostApp() -> String?      // For Settings UI
    func frontmostAppInfo() -> (name: String, bundleID: String)?
    var onAppChanged: ((String?) -> Void)?
  }
  ```

---

#### InputController.swift (Phase 3, updated Phase 5)
- **Responsibilities:**
  - Subclass `IMKInputController` for key event interception
  - Route keystroke → VietEngine → marked text or commit
  - Handle marked text display (composition preview with underline)
  - Detect hotkey combo (default Ctrl+Space) → toggle Vietnamese mode
  - Check `isVietnameseEnabled` flag → passthrough all keys when disabled
  - Commit text on space/punctuation/modifiers
  - Manage session lifecycle (activateServer/deactivateServer)
  - Observe UserDefaults for live Telex↔VNI switching

- **Key Entry Points:**
  - `handle(_:client:) -> Bool`: Primary key event handler (hotkey check first)
  - `isToggleHotkey(_ event:) -> Bool`: Matches event against stored hotkey
  - `toggleVietnamese()`: Flip `isVietnameseEnabled` and log
  - `activateServer()`: Reset engine state on focus gain
  - `deactivateServer()`: Commit pending composition on focus loss

- **Hotkey Toggle (Phase 5):**
  - Default: Ctrl+Space (stored in UserDefaults via HotkeyStore)
  - Checked BEFORE all other key handling so it works in all modes
  - Global-level: intercepts hotkey even in excluded apps
  - Toggles `isVietnameseEnabled` → disables Vietnamese until hotkey pressed again

- **Modifier Key Handling:**
  - Cmd, Ctrl, Option: pass through without intercepting (commit pending first)
  - Shift + letter: detect via `event.modifierFlags.contains(.shift)`, pass `isUppercase: true` to VietEngine
  - Caps Lock: auto-detect via event flags, same behavior

- **Special Keys:**
  - Backspace (keyCode 51): translate to `\u{08}` and process through VietEngine to undo last keystroke
  - Navigation (arrows, Home/End, PageUp/PageDown): commit pending, pass through
  - Function keys (F5-F20): commit pending, pass through
  - Escape: commit pending, pass through

- **UserDefaults Observation:**
  - Watch `inputMethod` key in standard defaults → recreate VietEngine on change
  - Watch `isVietnameseEnabled` key via InputController.handle() check
  - No app restart needed for live switching

#### main.swift
- **Responsibilities:**
  - Manual NSApplication setup (no `@main` decorator)
  - Wire AppDelegate to NSApplication.shared
  - Keep app alive for background operation

- **Key Implementation:**
  ```swift
  let delegate = AppDelegate()
  NSApplication.shared.delegate = delegate
  NSApplication.shared.run()
  ```

#### SettingsWindowController.swift (NEW — Phase 5)
- **Responsibilities:**
  - Wrap SwiftUI SettingsView in NSPanel (420×340px)
  - Window persists across open/close (isReleasedWhenClosed = false)
  - Provide `showSettings()` to activate window and bring app to front

- **Key Implementation:**
  ```swift
  final class SettingsWindowController: NSWindowController {
    convenience init() {
      let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
        styleMask: [.titled, .closable, .miniaturizable],
        backing: .buffered, defer: false
      )
      panel.title = "Pankey Settings"
      panel.contentViewController = NSHostingController(rootView: SettingsView())
      panel.isReleasedWhenClosed = false
      self.init(window: panel)
    }
  }
  ```

#### SettingsView.swift (NEW — Phase 5)
- **Responsibilities:**
  - Root container with custom pixel-style tab bar
  - Switch between 3 tabs: GENERAL, EXCLUDED, CONVERT
  - Apply PixelTheme styling to entire view

- **Tab Structure:**
  - **GENERAL** (GeneralSettingsView): VI/EN toggle, method picker, hotkey recorder
  - **EXCLUDED** (ExclusionListView): Add/remove apps from exclusion list
  - **CONVERT** (ConvertToolView): Placeholder for Phase 6 text conversion tool

#### GeneralSettingsView.swift (NEW — Phase 5)
- **Responsibilities:**
  - VI/EN toggle using PixelToggleStyle
  - Telex/VNI method picker (buttons)
  - Hotkey recorder UI: label showing current hotkey, CHANGE/CANCEL button
  - Display version info

- **Hotkey Recorder:**
  - Calls `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` when "CHANGE" clicked
  - Records keystroke → saves via `HotkeyStore.save(keyCode:modifiers:)`
  - Updates label via `HotkeyStore.displayLabel()`
  - Escape key cancels recording

#### ExclusionListView.swift (NEW — Phase 5)
- **Responsibilities:**
  - Display list of excluded apps (from AppExclusionManager)
  - Add current foremost app via AppExclusionManager.addFrontmostApp()
  - Remove apps from list
  - Observe AppExclusionManager changes for live UI updates

#### ConvertToolView.swift (NEW — Phase 6)
- **Responsibilities:**
  - Full SwiftUI implementation of text conversion tool
  - Format pickers (FROM / TO): Unicode, Telex, VNI
  - Side-by-side INPUT / OUTPUT TextEditors with live preview
  - PASTE & CONVERT button (reads from NSPasteboard.general)
  - COPY RESULT button with 1.5s "COPIED!" feedback
  - Integrates with ConversionService for Telex↔Unicode, VNI↔Unicode, Unicode→Telex conversion
  - Uses PixelTheme for 8-bit pixel aesthetic throughout

#### PixelUI/PixelTheme.swift (NEW — Phase 5)
- **Provides:**
  - Color palette: `background`, `surface`, `accent`, `text`, `textDim`, `danger`, `border`
  - Typography: `pixelFont(size:)` → Press Start 2P custom font
  - Spacing grid: 8px base unit
  - Color hex initializer for Color(hex: "#1a1a2e")

#### PixelUI/PixelButtonStyle.swift (NEW — Phase 5)
- **Styles:** `.primary` (accent bg), `.secondary` (surface bg), `.danger` (red bg)
- **Applies:** PixelTheme font, border, padding

#### PixelUI/PixelBorderModifier.swift (NEW — Phase 5)
- **Provides:** `.pixelBorder(color:)` view modifier for neon borders

#### PixelUI/PixelToggleStyle.swift (NEW — Phase 5)
- **Provides:** Toggle with pixel on/off appearance, accent color

#### Info.plist
- **Critical Settings:**
  - `InputMethodConnectionName`: Telex or VNI identifier (e.g., `com.petereaI.Pankey`)
  - `InputMethodServerControllerClass`: Must match `@objc(InputController)`
  - Bundle identifier, version, etc.

---

## Data Flow

### Key Event Pipeline (Phase 5)

```
NSEvent (keystroke from OS)
  ↓
InputController.handle(_:client:)
  ├─ [Hotkey check] isToggleHotkey()? → toggleVietnamese(), return true ✓ (Phase 5)
  ├─ [VI/EN check] isVietnameseEnabled? → if false, passthrough all keys
  ├─ [Exclusion check] AppExclusionManager.isCurrentAppExcluded()? → commitPending(), passthrough
  ├─ [Modifier check] Cmd/Ctrl/Option? → commitPending(), passthrough
  ├─ [Passthrough check] Escape/Arrows/F-keys? → commitPending(), passthrough
  └─ [Composition] Regular key
      ↓
      VietEngine.handleKey(char)
        ├─ .composing(preview) → updateMarkedText() → show preview with underline
        ├─ .commit(text, overflow) → clearMarkedText(), insertText(text), process overflow
        └─ .passthrough → return false (let app handle it)
      ↓
      Client app (TextEdit, Chrome, Terminal, etc.)
```

### Session Lifecycle

```
App gains focus
  ↓ activateServer()
  → engine.reset()

User types
  ↓ handle(_:client:) repeatedly
  → VietEngine state updated

App loses focus
  ↓ deactivateServer()
  → commitPending(client) [inserts pending composition]
  → engine.reset()
```

### Settings Sync (Live)

```
User changes input method in Settings UI (Phase 5)
  ↓ UserDefaults writes `inputMethod` key
  ↓ NotificationCenter broadcasts
  ↓ InputController observes
  → syncInputMethod() → engine = VietEngine(method: newMethod)
  ↓ Next keystroke uses new method (no restart)
```

### Menu Bar & Settings UI (Phase 5)

```
AppDelegate.applicationDidFinishLaunching()
  ↓ menuBarController.setup()
  ├─ Create NSStatusItem in menu bar
  ├─ Build menu: Toggle, Method picker, Settings, Quit
  ├─ Register UserDefaults defaults
  └─ Observe defaults changes → updateIcon()

User clicks "VI" icon → dropdown menu appears
  ├─ "Toggle VI/EN" → toggleInputMode() → flip isVietnameseEnabled
  ├─ "Telex" / "VNI" → selectMethod() → write inputMethod key
  └─ "Settings…" → openSettings() → SettingsWindowController.showSettings()

SettingsWindowController.showSettings()
  ↓ NSPanel(SettingsView) appears with 3 tabs
  ├─ GENERAL: VI/EN toggle, Telex/VNI picker, hotkey recorder
  ├─ EXCLUDED: per-app exclusion list
  └─ CONVERT: placeholder for Phase 6

User records hotkey in GeneralSettingsView
  ↓ NSEvent.addLocalMonitorForEvents() captures next keystroke
  ↓ HotkeyStore.save(keyCode, modifiers)
  ↓ InputController.isToggleHotkey() matches future keystrokes
  ↓ On match: toggleVietnamese() flips VI/EN mode
```

---

## Build & Installation

### Build
```bash
cd /Users/petereai/Desktop/projects/petereaI/pankey
swift build
xcodebuild -scheme PankeyMac -configuration Debug build
```

### Type Checking
```bash
swiftc -typecheck PankeyMac/*.swift
swiftc -typecheck -I.build/debug PankeyCore/Sources/PankeyCore/*.swift
```

### Install to System
```bash
cp -r build/Debug/PankeyMac.app ~/Library/Input\ Methods/
killall PankeyMac 2>/dev/null
open ~/Library/Input\ Methods/PankeyMac.app
```

### Register in System Settings
1. System Settings > Keyboard > Input Sources
2. Click + to add
3. Search for "Pankey" → select and add

---

## Testing Checklist

- [x] Phase 3 implementation verified: all files compile with `swiftc -typecheck`
- [x] Key event pipeline functional: Telex composition, marked text display
- [x] Modifier passthrough: Cmd+C, Ctrl+A, Option+arrows unaffected
- [x] Backspace during composition: undoes last keystroke
- [x] Uppercase detection: Shift+key, Caps Lock support
- [x] Session lifecycle: activateServer/deactivateServer on focus change
- [x] UserDefaults observation: live Telex↔VNI switching
- [x] App exclusion: excluded apps pass all keys through, pending buffer committed on switch
- [x] Phase 5 UI verified: Menu bar icon appears, Settings window opens, tabs functional
- [x] Hotkey toggle: Ctrl+Space (default) toggles VI/EN mode globally
- [x] VI/EN toggle: Menu bar icon updates, icon toggle in Settings works
- [x] Input method picker: Telex/VNI switching via menu and Settings
- [x] Hotkey recorder: captures and displays hotkey, Escape cancels

Pending (Phase 7+):
- [ ] Comprehensive unit & integration tests
- [ ] Distribution & release (Phase 8, deferred pending Developer ID cert)

---

## Next Phase

**Phase 7: Unit & Integration Tests**
- Comprehensive unit tests for VietEngine, ConversionService
- Integration tests for IMK pipeline
- Test coverage for all composition scenarios (Telex, VNI, Unicode)

---

## Implementation Timeline

| Phase | Name | Status | Dates |
|-------|------|--------|-------|
| 1 | Project Setup & Xcode Config | Complete | 2026-04-11 |
| 2 | PankeyCore Vietnamese Engine | Complete | 2026-04-11 |
| 3 | IMK Integration | Complete | 2026-04-11 |
| 4 | App Exclusion Feature | Complete | 2026-04-12 |
| 5 | Menu Bar & Settings UI | Complete | 2026-04-12 |
| 6 | Text Conversion Tool | Complete | 2026-04-12 |
| 7 | Unit & Integration Tests | Pending | TBD |
| 8 | Distribution & Release | Deferred | (no Developer ID yet) |

---

## Known Limitations & Future Work

- **Phase 8 deferred:** No Developer ID certificate yet; notarization skipped
- **Marked text not supported:** Some apps (Terminal, SSH) don't support marked text; fallback to passthrough
- **Backspace on committed text:** Standard backspace only; syllable-undo deferred to v2
- **Global hotkey:** Ctrl+Space works but may conflict with other apps; custom hotkey recording available in Settings
- **Settings persistence:** All settings stored in UserDefaults; no iCloud sync or profile export

---

## References

- [IMK Swift Research Report](../plans/260411-1742-pankey-vietnamese-ime/reports/researcher-260411-1739-imk-swift-research.md)
- [Vietnamese Composition Algorithm Report](../plans/260411-1742-pankey-vietnamese-ime/reports/researcher-260411-1739-vietnamese-ime-composition-algorithm.md)
- [Main Implementation Plan](../plans/260411-1742-pankey-vietnamese-ime/plan.md)
