# Codebase Summary — Pankey Vietnamese IME

**Last updated:** 2026-04-11 | **Phase:** 3 (IMK Integration Complete)

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
│   ├── AppDelegate.swift           # IMKServer initialization
│   ├── InputController.swift       # IMKInputController → VietEngine bridge
│   ├── main.swift                  # Manual AppDelegate wiring (no @main)
│   └── Info.plist                  # Input method registration
└── Pankey.xcodeproj/    # Xcode project
```

---

## Component Details

### PankeyCore (Swift Package)

**Purpose:** Pure Swift Vietnamese composition engine, no platform dependencies.

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

---

### PankeyMac (macOS Application)

**Purpose:** Wire VietEngine into macOS InputMethodKit, providing system-wide Vietnamese typing.

#### AppDelegate.swift
- **Responsibilities:**
  - Initialize `IMKServer` with connection name from Info.plist
  - Store server as property (prevents deallocation)
  - Register input method with macOS
  - Set app to accessory mode (no dock icon, background agent behavior)

- **Key Implementation:**
  ```swift
  @objc class AppDelegate: NSObject, NSApplicationDelegate {
    var server: IMKServer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
      guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String else { ... }
      server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
      NSApp.setActivationPolicy(.accessory)
    }
  }
  ```

#### InputController.swift (NEW — Phase 3)
- **Responsibilities:**
  - Subclass `IMKInputController` for key event interception
  - Route keystroke → VietEngine → marked text or commit
  - Handle marked text display (composition preview with underline)
  - Commit text on space/punctuation/modifiers
  - Manage session lifecycle (activateServer/deactivateServer)
  - Observe UserDefaults for live Telex↔VNI switching

- **Key Entry Points:**
  - `handle(_:client:) -> Bool`: Primary key event handler
  - `activateServer()`: Reset engine state on focus gain
  - `deactivateServer()`: Commit pending composition on focus loss

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
  - Watch `inputMethod` key in standard defaults
  - On change: recreate VietEngine with new method, no restart needed

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

#### Info.plist
- **Critical Settings:**
  - `InputMethodConnectionName`: Telex or VNI identifier (e.g., `com.petereaI.Pankey`)
  - `InputMethodServerControllerClass`: Must match `@objc(InputController)`
  - Bundle identifier, version, etc.

---

## Data Flow

### Key Event Pipeline

```
NSEvent (keystroke from OS)
  ↓
InputController.handle(_:client:)
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
  → switchInputMethod(to: .vni) or .telex
  → engine = VietEngine(method: newMethod)
  ↓ Next keystroke uses new method (no restart)
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

Pending (Phase 4+):
- [ ] App exclusion feature
- [ ] Menu bar settings UI
- [ ] Text conversion tool
- [ ] Comprehensive unit & integration tests

---

## Next Phase

**Phase 4: App Exclusion Feature**
- Implement per-app exclusion list (e.g., disable in Xcode, Terminal)
- Settings file: `~/.pankey/excluded-apps.json`
- Check bundle identifier on focus, skip IME if excluded

---

## Implementation Timeline

| Phase | Name | Status | Dates |
|-------|------|--------|-------|
| 1 | Project Setup & Xcode Config | Complete | 2026-04-11 |
| 2 | PankeyCore Vietnamese Engine | Complete | 2026-04-11 |
| 3 | IMK Integration | Complete | 2026-04-11 |
| 4 | App Exclusion Feature | Pending | Next |
| 5 | Menu Bar & Settings UI | Pending | TBD |
| 6 | Text Conversion Tool | Pending | TBD |
| 7 | Unit & Integration Tests | Pending | TBD |
| 8 | Distribution & Release | Deferred | (no Developer ID yet) |

---

## Known Limitations & Future Work

- **Phase 8 deferred:** No Developer ID certificate yet; notarization skipped
- **Marked text not supported:** Some apps (Terminal, SSH) don't support marked text; fallback to passthrough
- **Backspace on committed text:** Standard backspace only; syllable-undo deferred to v2
- **Hotkey toggle:** Planned for Phase 5 (default Ctrl+Space, configurable)

---

## References

- [IMK Swift Research Report](../plans/260411-1742-pankey-vietnamese-ime/reports/researcher-260411-1739-imk-swift-research.md)
- [Vietnamese Composition Algorithm Report](../plans/260411-1742-pankey-vietnamese-ime/reports/researcher-260411-1739-vietnamese-ime-composition-algorithm.md)
- [Main Implementation Plan](../plans/260411-1742-pankey-vietnamese-ime/plan.md)
