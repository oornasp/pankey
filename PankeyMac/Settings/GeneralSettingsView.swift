// GeneralSettingsView.swift — settings tab: VI/EN toggle, input method picker, hotkey modifier picker
import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("isVietnameseEnabled") private var isEnabled = true
    @AppStorage("inputMethod") private var inputMethod = "telex"
    @State private var selectedMods: NSEvent.ModifierFlags = {
        HotkeyStore.load().modifiers.intersection([.control, .option, .command, .shift])
    }()

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

            // Toggle hotkey modifier picker — select any combo of CMD / OPT / CTRL / SHIFT
            VStack(alignment: .leading, spacing: PixelTheme.spacing) {
                Text("TOGGLE HOTKEY")
                    .font(PixelTheme.pixelFont(size: 8))
                    .foregroundColor(PixelTheme.textDim)
                HStack(spacing: PixelTheme.spacing) {
                    ForEach(Self.modifierOptions, id: \.label) { opt in
                        Button(opt.label) { toggleModifier(opt.flag) }
                            .buttonStyle(PixelButtonStyle(
                                variant: selectedMods.contains(opt.flag) ? .primary : .secondary
                            ))
                    }
                }
                Text(selectedMods.isEmpty ? "SELECT AT LEAST ONE KEY" : hotkeyPreview)
                    .font(PixelTheme.pixelFont(size: 7))
                    .foregroundColor(selectedMods.isEmpty ? PixelTheme.accent : PixelTheme.textDim)
            }

            Spacer()

            Text("PANKEY v1.0.0")
                .font(PixelTheme.pixelFont(size: 7))
                .foregroundColor(PixelTheme.textDim)
        }
        .padding(PixelTheme.spacing * 2)
        .background(PixelTheme.background)
    }

    // MARK: - Modifier picker

    private struct ModifierOption {
        let label: String
        let flag: NSEvent.ModifierFlags
    }

    private static let modifierOptions: [ModifierOption] = [
        .init(label: "CMD",   flag: .command),
        .init(label: "OPT",   flag: .option),
        .init(label: "CTRL",  flag: .control),
        .init(label: "SHIFT", flag: .shift),
    ]

    private var hotkeyPreview: String {
        var parts: [String] = []
        if selectedMods.contains(.command) { parts.append("CMD") }
        if selectedMods.contains(.option)  { parts.append("OPT") }
        if selectedMods.contains(.control) { parts.append("CTRL") }
        if selectedMods.contains(.shift)   { parts.append("SHIFT") }
        return parts.joined(separator: " + ")
    }

    private func toggleModifier(_ flag: NSEvent.ModifierFlags) {
        var mods = selectedMods
        if mods.contains(flag) {
            mods.remove(flag)
        } else {
            mods.insert(flag)
        }
        guard !mods.isEmpty else { return } // require at least one modifier
        selectedMods = mods
        HotkeyStore.save(keyCode: HotkeyStore.modifierOnlyKeyCode, modifiers: mods)
    }
}

// MARK: - HotkeyStore — persistence for toggle hotkey preference

enum HotkeyStore {
    private static let keyCodeKey   = "toggleHotkeyKeyCode"
    private static let modifiersKey = "toggleHotkeyModifiers"

    // Default: CTRL only (modifier-only)
    static let defaultModifiers: NSEvent.ModifierFlags = .control
    // All modifier-only hotkeys use this sentinel keyCode
    static let modifierOnlyKeyCode: UInt16 = 0xFFFF

    static func save(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        let cleaned = modifiers.intersection([.control, .option, .command, .shift])
        UserDefaults.standard.set(Int(keyCode), forKey: keyCodeKey)
        UserDefaults.standard.set(Int(cleaned.rawValue), forKey: modifiersKey)
    }

    static func load() -> (keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        // Hotkeys are always modifier-only now — ignore any legacy keyCode in UserDefaults
        let rawMods = UserDefaults.standard.object(forKey: modifiersKey)
            .flatMap { $0 as? Int }
            .map { UInt(bitPattern: $0) }
        let mods = rawMods.map { NSEvent.ModifierFlags(rawValue: $0) } ?? defaultModifiers
        return (keyCode: modifierOnlyKeyCode, modifiers: mods)
    }
}
