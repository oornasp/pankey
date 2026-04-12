// GeneralSettingsView.swift — settings tab: VI/EN toggle, input method picker, hotkey recorder
import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("isVietnameseEnabled") private var isEnabled = true
    @AppStorage("inputMethod") private var inputMethod = "telex"
    @State private var isRecordingHotkey = false
    @State private var hotkeyLabel = HotkeyStore.displayLabel()
    @State private var hotkeyMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: PixelTheme.spacing * 2) {
            Text("GENERAL")
                .font(PixelTheme.pixelFont(size: 10))
                .foregroundColor(PixelTheme.accent)

            Divider().background(PixelTheme.border)

            // VI/EN toggle
            Toggle("Vietnamese Input", isOn: $isEnabled)
                .toggleStyle(PixelToggleStyle())

            // Input method picker (Telex / VNI)
            VStack(alignment: .leading, spacing: PixelTheme.spacing) {
                Text("INPUT METHOD")
                    .font(PixelTheme.pixelFont(size: 8))
                    .foregroundColor(PixelTheme.textDim)
                HStack(spacing: PixelTheme.spacing) {
                    ForEach(["telex", "vni"], id: \.self) { method in
                        Button(method.uppercased()) { inputMethod = method }
                            .buttonStyle(PixelButtonStyle(
                                variant: inputMethod == method ? .primary : .secondary
                            ))
                    }
                }
            }

            // Toggle hotkey recorder
            VStack(alignment: .leading, spacing: PixelTheme.spacing) {
                Text("TOGGLE HOTKEY")
                    .font(PixelTheme.pixelFont(size: 8))
                    .foregroundColor(PixelTheme.textDim)
                HStack(spacing: PixelTheme.spacing) {
                    Text(isRecordingHotkey ? "PRESS KEY..." : hotkeyLabel)
                        .font(PixelTheme.pixelFont(size: 8))
                        .foregroundColor(isRecordingHotkey ? PixelTheme.accent : PixelTheme.text)
                        .frame(minWidth: 100)
                        .padding(.horizontal, PixelTheme.spacing)
                        .padding(.vertical, 6)
                        .pixelBorder(color: isRecordingHotkey ? PixelTheme.accent : PixelTheme.border)
                    Button(isRecordingHotkey ? "CANCEL" : "CHANGE") {
                        isRecordingHotkey ? cancelRecording() : startRecording()
                    }
                    .buttonStyle(PixelButtonStyle(variant: isRecordingHotkey ? .danger : .secondary))
                }
            }

            Spacer()

            Text("PANKEY v1.0.0")
                .font(PixelTheme.pixelFont(size: 7))
                .foregroundColor(PixelTheme.textDim)
        }
        .padding(PixelTheme.spacing * 2)
        .background(PixelTheme.background)
        .onDisappear { cancelRecording() }
    }

    // MARK: - Hotkey recording

    private func startRecording() {
        isRecordingHotkey = true
        hotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape cancels recording
            if event.keyCode == 53 {
                self.cancelRecording()
                return nil
            }
            HotkeyStore.save(keyCode: event.keyCode, modifiers: event.modifierFlags)
            self.hotkeyLabel = HotkeyStore.displayLabel()
            self.cancelRecording()
            return nil  // consume the event
        }
    }

    private func cancelRecording() {
        if let monitor = hotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            hotkeyMonitor = nil
        }
        isRecordingHotkey = false
    }
}

// MARK: - HotkeyStore — persistence for toggle hotkey preference

enum HotkeyStore {
    private static let keyCodeKey   = "toggleHotkeyKeyCode"
    private static let modifiersKey = "toggleHotkeyModifiers"

    // Default: Ctrl+Space (keyCode 49, NSEvent.ModifierFlags.control)
    static let defaultKeyCode: UInt16 = 49
    static let defaultModifiers: NSEvent.ModifierFlags = .control

    static func save(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        let cleaned = modifiers.intersection([.control, .option, .command, .shift])
        UserDefaults.standard.set(Int(keyCode), forKey: keyCodeKey)
        UserDefaults.standard.set(Int(cleaned.rawValue), forKey: modifiersKey)
    }

    static func load() -> (keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        let kc = UserDefaults.standard.object(forKey: keyCodeKey)
            .flatMap { $0 as? Int }
            .map { UInt16($0) } ?? defaultKeyCode
        let rawMods = UserDefaults.standard.object(forKey: modifiersKey)
            .flatMap { $0 as? Int }
            .map { UInt(bitPattern: $0) }
        let mods = rawMods.map { NSEvent.ModifierFlags(rawValue: $0) } ?? defaultModifiers
        return (keyCode: kc, modifiers: mods)
    }

    static func displayLabel() -> String {
        let (kc, mods) = load()
        var parts: [String] = []
        if mods.contains(.control) { parts.append("^") }
        if mods.contains(.option)  { parts.append("~") }
        if mods.contains(.shift)   { parts.append("+") }
        if mods.contains(.command) { parts.append("*") }
        parts.append(keyLabel(for: kc))
        return parts.joined(separator: "")
    }

    private static func keyLabel(for keyCode: UInt16) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        default:
            // Use CGEventKeyboardGetUnicodeString equivalent via NSEvent character lookup
            return "Key(\(keyCode))"
        }
    }
}
