// InputController.swift — IMKInputController subclass: key event pipeline for Pankey IME
import InputMethodKit
import PankeyCore

// MARK: - Key code constants

private enum KeyCode {
    static let `return`: UInt16  = 36
    static let tab: UInt16       = 48
    static let delete: UInt16    = 51   // Backspace key on Mac keyboards
    static let escape: UInt16    = 53
    static let forwardDelete: UInt16 = 117
    // Navigation
    static let navigation: Set<UInt16> = [123, 124, 125, 126, 115, 119, 116, 121]
    // Function keys F1-F15
    static let functionKeys: Set<UInt16> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113]
}

// MARK: - InputController

// ObjC name MUST match InputMethodServerControllerClass in Info.plist
@objc(InputController)
class InputController: IMKInputController {

    private var engine: VietEngine
    private var currentMethod: InputMethod = .telex
    private var defaultsObserver: NSObjectProtocol?

    // MARK: - Lifecycle

    override init!(server: IMKServer!, delegate: Any!, client textInput: Any!) {
        engine = VietEngine(method: .telex)
        super.init(server: server, delegate: delegate, client: textInput)
        syncInputMethod()
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncInputMethod()
        }
    }

    deinit {
        if let obs = defaultsObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Primary key handler

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, event.type == .keyDown else { return false }

        // Toggle hotkey: check before everything else so it works in all modes
        if isToggleHotkey(event) {
            toggleVietnamese()
            return true
        }

        // VI/EN mode: pass through all keys when Vietnamese is disabled
        guard UserDefaults.standard.bool(forKey: "isVietnameseEnabled") else { return false }

        // App exclusion check — pass all keys through when frontmost app is excluded
        if AppExclusionManager.shared.isCurrentAppExcluded() {
            if let client = sender as? IMKTextInput {
                commitPending(client: client)
            }
            return false
        }

        guard let client = sender as? IMKTextInput else {
            NSLog("Pankey: client does not conform to IMKTextInput")
            return false
        }

        // Modifier combos (Cmd/Ctrl/Option) pass through after flushing composition
        let mods = event.modifierFlags
        if mods.contains(.command) || mods.contains(.control) || mods.contains(.option) {
            commitPending(client: client)
            return false
        }

        // Ignore key repeats for all keys (prevents tone-key flooding)
        if event.isARepeat { return false }

        return handleKeyDown(event, client: client)
    }

    // MARK: - Key routing

    private func handleKeyDown(_ event: NSEvent, client: IMKTextInput) -> Bool {
        let keyCode = event.keyCode

        // Navigation / function keys: flush and pass through
        if KeyCode.navigation.contains(keyCode) || KeyCode.functionKeys.contains(keyCode)
            || keyCode == KeyCode.escape || keyCode == KeyCode.forwardDelete {
            commitPending(client: client)
            return false
        }

        // Detect uppercase: Shift or Caps Lock
        let mods = event.modifierFlags
        let isUppercase = mods.contains(.shift) || mods.contains(.capsLock)

        // Delete/Backspace: translate keyCode 51 → BS character for VietEngine
        if keyCode == KeyCode.delete {
            let result = engine.handleKey("\u{08}", isUppercase: isUppercase)
            return applyResult(result, client: client)
        }

        guard let chars = event.characters, let key = chars.first else { return false }

        let result = engine.handleKey(key, isUppercase: isUppercase)
        return applyResult(result, client: client)
    }

    // MARK: - Engine result dispatch

    private func applyResult(_ result: EngineResult, client: IMKTextInput) -> Bool {
        switch result {
        case .composing(let preview):
            updateMarkedText(preview, client: client)
            return true

        case .commit(let text, let remainder):
            clearMarkedText(client: client)
            if !text.isEmpty {
                client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
            }
            if let rem = remainder {
                if rem == " " {
                    client.insertText(" ", replacementRange: NSRange(location: NSNotFound, length: 0))
                } else {
                    // Non-space overflow key starts a new composition cycle
                    let mods = NSApp.currentEvent?.modifierFlags ?? []
                    let isUppercase = mods.contains(.shift) || mods.contains(.capsLock)
                    let nextResult = engine.handleKey(rem, isUppercase: isUppercase)
                    return applyResult(nextResult, client: client)
                }
            }
            return true

        case .passthrough:
            return false
        }
    }

    // MARK: - Marked text helpers

    private func updateMarkedText(_ text: String, client: IMKTextInput) {
        let attrs = mark(forStyle: kTSMHiliteSelectedConvertedText,
                         at: NSRange(location: 0, length: text.utf16.count))
        client.setMarkedText(
            NSAttributedString(string: text, attributes: attrs as? [NSAttributedString.Key: Any]),
            selectionRange: NSRange(location: text.utf16.count, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
    }

    private func clearMarkedText(client: IMKTextInput) {
        client.setMarkedText("",
            selectionRange: NSRange(location: 0, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    /// Commit any in-progress composition to the client app
    private func commitPending(client: IMKTextInput) {
        let pending = engine.currentPreview
        guard !pending.isEmpty else { return }
        clearMarkedText(client: client)
        client.insertText(pending, replacementRange: NSRange(location: NSNotFound, length: 0))
        engine.reset()
    }

    // MARK: - Session lifecycle

    override func activateServer(_ sender: Any!) {
        NSLog("Pankey: activateServer")
        engine.reset()
    }

    override func deactivateServer(_ sender: Any!) {
        NSLog("Pankey: deactivateServer")
        if let client = sender as? IMKTextInput {
            commitPending(client: client)
        }
        engine.reset()
    }

    // MARK: - VI/EN toggle hotkey

    private func isToggleHotkey(_ event: NSEvent) -> Bool {
        let (storedKeyCode, storedMods) = HotkeyStore.load()
        let eventMods = event.modifierFlags.intersection([.control, .option, .command, .shift])
        let storedMods2 = storedMods.intersection([.control, .option, .command, .shift])
        return event.keyCode == storedKeyCode && eventMods == storedMods2
    }

    private func toggleVietnamese() {
        let key = "isVietnameseEnabled"
        let current = UserDefaults.standard.bool(forKey: key)
        UserDefaults.standard.set(!current, forKey: key)
        NSLog("Pankey: Vietnamese toggled → \(!current)")
    }

    // MARK: - Settings sync

    /// Recreate engine when UserDefaults `inputMethod` key changes (Telex ↔ VNI)
    private func syncInputMethod() {
        let stored = UserDefaults.standard.string(forKey: "inputMethod") ?? "telex"
        let newMethod: InputMethod = stored == "vni" ? .vni : .telex
        guard newMethod != currentMethod else { return }
        currentMethod = newMethod
        engine = VietEngine(method: newMethod)
        NSLog("Pankey: input method → \(stored)")
    }
}
