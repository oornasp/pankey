// KeyboardEventTap.swift — CGEventTap-based keyboard interceptor for Pankey
// Replaces InputMethodKit approach: works as a standalone app like OpenKey/Unikey
import Cocoa
import PankeyCore

// Sentinel stamped on events we post ourselves — prevents infinite re-interception
private let kPankeyEventMarker: Int64 = 0x506B7900

// MARK: - Key code constants

private enum KeyCode {
    static let `return`: Int64      = 36
    static let tab: Int64           = 48
    static let delete: Int64        = 51   // Backspace
    static let escape: Int64        = 53
    static let forwardDelete: Int64 = 117
    static let navigation: Set<Int64> = [123, 124, 125, 126, 115, 119, 116, 121]
    static let functionKeys: Set<Int64> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113]
}

// MARK: - KeyboardEventTap

final class KeyboardEventTap {

    private var engine: VietEngine
    // Number of raw ASCII chars currently sitting in the text field for the current composition.
    // Used to know how many backspaces to send when committing Vietnamese text.
    private var rawCharsInBuffer: Int = 0

    // True whenever the engine has returned .composing at least once since last reset.
    // Used to suppress raw keystrokes and show Unicode preview immediately instead.
    private var isComposing: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Re-entrancy guard: set true while we are posting replacement events so we
    // don't intercept our own backspace / unicode events in the tap callback.
    private var isFlushing = false

    // Tracks peak modifier combination between full-releases (union prevents early-release erasure)
    private var modifierPeak: NSEvent.ModifierFlags = []

    private var defaultsObserver: NSObjectProtocol?

    init() {
        let method: InputMethod = UserDefaults.standard.string(forKey: "inputMethod") == "vni" ? .vni : .telex
        engine = VietEngine(method: method)
        observeDefaults()
    }

    deinit {
        stop()
        if let obs = defaultsObserver { NotificationCenter.default.removeObserver(obs) }
    }

    // MARK: - Lifecycle

    func start() {
        // Explicit UInt64 cast to guarantee flagsChanged bit is set correctly
        let keyDownBit    = CGEventMask(1) << CGEventType.keyDown.rawValue
        let flagsChangedBit = CGEventMask(1) << CGEventType.flagsChanged.rawValue
        let eventMask = keyDownBit | flagsChangedBit

        // The callback must be a C function pointer; bridge to self via userInfo opaque pointer
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let handler = Unmanaged<KeyboardEventTap>.fromOpaque(refcon).takeUnretainedValue()
                return handler.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = tap else {
            NSLog("Pankey: CGEventTap creation failed — Accessibility permission not granted")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("Pankey: CGEventTap started")
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Event handler (called from C callback on each keyDown)

    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Pass through events we posted ourselves (prevents infinite loop)
        if event.getIntegerValueField(.eventSourceUserData) == kPankeyEventMarker {
            return Unmanaged.passRetained(event)
        }

        // While posting replacement events, let everything through
        if isFlushing { return Unmanaged.passRetained(event) }

        // Modifier-only toggle hotkey: track peak modifier combination via flagsChanged.
        // CGEventTap with Accessibility permission is the single authoritative handler —
        // no NSEvent global monitor needed (avoids Input Monitoring requirement + double-fire).
        if type == .flagsChanged {
            let rawMods = UInt(event.flags.rawValue)
            let currentMods = NSEvent.ModifierFlags(rawValue: rawMods).intersection([.control, .option, .command, .shift])
            if currentMods.isEmpty {
                let (_, storedMods) = HotkeyStore.load()
                let targetMods = storedMods.intersection([.control, .option, .command, .shift])
                if !modifierPeak.isEmpty && modifierPeak == targetMods { toggleVietnamese() }
                modifierPeak = []
            } else {
                modifierPeak = modifierPeak.union(currentMods)
            }
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // --- Vietnamese mode off: pass all keys through ---
        guard UserDefaults.standard.bool(forKey: "isVietnameseEnabled") else {
            return Unmanaged.passRetained(event)
        }

        // --- Excluded app: flush composition and pass through ---
        if AppExclusionManager.shared.isCurrentAppExcluded() {
            resetComposition()
            return Unmanaged.passRetained(event)
        }

        // --- Modifier combos (Cmd/Ctrl/Opt): flush and pass through ---
        // Also clear modifierPeak so releasing the modifier afterward does NOT trigger the toggle hotkey.
        // Without this, CMD+C, CTRL+Z, etc. would accidentally fire the toggle on modifier release.
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            modifierPeak = []
            resetComposition()
            return Unmanaged.passRetained(event)
        }

        // --- Navigation / function / escape / forward-delete: flush and pass through ---
        if KeyCode.navigation.contains(keyCode) || KeyCode.functionKeys.contains(keyCode)
            || keyCode == KeyCode.escape || keyCode == KeyCode.forwardDelete {
            resetComposition()
            return Unmanaged.passRetained(event)
        }

        // --- Return / Tab: flush composition, then pass key through ---
        if keyCode == KeyCode.return || keyCode == KeyCode.tab {
            resetComposition()
            return Unmanaged.passRetained(event)
        }

        let isUppercase = flags.contains(.maskShift) || flags.contains(.maskAlphaShift)

        // --- Backspace during composition: consume it, recompute engine state ---
        if keyCode == KeyCode.delete {
            if rawCharsInBuffer > 0 {
                rawCharsInBuffer -= 1
                let nextResult = engine.handleKey("\u{08}", isUppercase: isUppercase)
                switch nextResult {
                case .composing(let preview):
                    // Engine still has chars: delete old preview, post new preview
                    isFlushing = true
                    postBackspaces(count: rawCharsInBuffer + 1)   // +1 = erase old preview char
                    postUnicodeText(preview)
                    rawCharsInBuffer = preview.count
                    isFlushing = false
                    return nil   // suppress backspace
                case .commit(let text, _):
                    // Buffer emptied by backspace
                    isFlushing = true
                    postBackspaces(count: rawCharsInBuffer + 1)
                    postUnicodeText(text)
                    rawCharsInBuffer = 0
                    isComposing = false
                    isFlushing = false
                    return nil
                case .passthrough:
                    isComposing = false
                    rawCharsInBuffer = 0
                    return Unmanaged.passRetained(event)
                }
            }
            // Nothing in our buffer — let system handle backspace normally
            engine.reset()
            isComposing = false
            return Unmanaged.passRetained(event)
        }

        // --- Extract the character from the event ---
        var length = 1
        var chars = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &length, unicodeString: &chars)
        guard length > 0, let scalar = Unicode.Scalar(chars[0]), let key = String(scalar).first else {
            return Unmanaged.passRetained(event)
        }

        // --- Feed into Vietnamese composition engine ---
        let result = engine.handleKey(key, isUppercase: isUppercase)

        switch result {
        case .composing(let preview):
            // Intercept the raw key: delete it, post Unicode preview immediately.
            // This gives the user live feedback — việ instead of vieejt.
            isComposing = true
            isFlushing = true
            postBackspaces(count: rawCharsInBuffer)
            postUnicodeText(preview)
            rawCharsInBuffer = preview.count
            isFlushing = false
            return nil   // suppress raw key event

        case .commit(let text, let remainder):
            // Suppress the triggering key; replace raw composition with Vietnamese text
            isFlushing = true
            postBackspaces(count: rawCharsInBuffer)
            postUnicodeText(text)
            rawCharsInBuffer = 0
            isFlushing = false

            // Handle the overflow character (e.g. space, punctuation, or next letter)
            if let rem = remainder {
                if rem == " " {
                    postUnicodeText(" ")
                } else {
                    // Re-feed overflow key into a fresh engine cycle
                    let nextResult = engine.handleKey(rem, isUppercase: isUppercase)
                    switch nextResult {
                    case .composing(let preview):
                        rawCharsInBuffer += 1
                        // Post the raw overflow char so it's visible in the text field
                        postUnicodeText(String(preview.last ?? rem))
                    case .commit(let t2, _):
                        postUnicodeText(t2)
                    case .passthrough:
                        postUnicodeText(String(rem))
                    }
                }
            }
            return nil   // original event consumed

        case .passthrough:
            return Unmanaged.passRetained(event)
        }
    }

    // MARK: - Composition reset (on context switch / modifier combo)

    /// Reset engine and buffer without sending any backspaces.
    /// Raw chars remain in the text field as-is (acceptable on app-switch mid-word).
    private func resetComposition() {
        engine.reset()
        rawCharsInBuffer = 0
        isComposing = false
    }

    // MARK: - Post helpers

    /// Send N backspace key events to erase raw chars in the active text field
    private func postBackspaces(count: Int) {
        guard count > 0 else { return }
        let src = CGEventSource(stateID: .combinedSessionState)
        for _ in 0..<count {
            let down = CGEvent(keyboardEventSource: src, virtualKey: 51, keyDown: true)
            let up   = CGEvent(keyboardEventSource: src, virtualKey: 51, keyDown: false)
            down?.setIntegerValueField(.eventSourceUserData, value: kPankeyEventMarker)
            up?.setIntegerValueField(.eventSourceUserData, value: kPankeyEventMarker)
            down?.post(tap: .cgAnnotatedSessionEventTap)
            up?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    /// Post a Unicode string as synthetic key events into the active text field
    private func postUnicodeText(_ text: String) {
        guard !text.isEmpty else { return }
        let src = CGEventSource(stateID: .combinedSessionState)
        let utf16 = Array(text.utf16)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
        down?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        up?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        down?.setIntegerValueField(.eventSourceUserData, value: kPankeyEventMarker)
        up?.setIntegerValueField(.eventSourceUserData, value: kPankeyEventMarker)
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }

    // MARK: - VI/EN toggle

    private func toggleVietnamese() {
        let key = "isVietnameseEnabled"
        let current = UserDefaults.standard.bool(forKey: key)
        UserDefaults.standard.set(!current, forKey: key)
        NSLog("Pankey: Vietnamese toggled → \(!current)")
    }

    // MARK: - Settings sync

    private func observeDefaults() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncInputMethod()
        }
    }

    /// Recreate engine when user switches Telex ↔ VNI in Settings
    private func syncInputMethod() {
        let stored = UserDefaults.standard.string(forKey: "inputMethod") ?? "telex"
        let newMethod: InputMethod = stored == "vni" ? .vni : .telex
        engine = VietEngine(method: newMethod)
        rawCharsInBuffer = 0
        NSLog("Pankey: input method → \(stored)")
    }
}
