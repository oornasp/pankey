// AppDelegate.swift — Application bootstrap for Pankey standalone app
// Uses CGEventTap (via KeyboardEventTap) instead of InputMethodKit
import Cocoa

@objc class AppDelegate: NSObject, NSApplicationDelegate {

    private let menuBarController = MenuBarController()
    private let keyboardTap = KeyboardEventTap()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "isVietnameseEnabled": true,
            "inputMethod": "telex",
            // Default toggle hotkey: CTRL only (0x40000 = NSEvent.ModifierFlags.control)
            "toggleHotkeyModifiers": Int(NSEvent.ModifierFlags.control.rawValue),
            "toggleHotkeyKeyCode": Int(HotkeyStore.modifierOnlyKeyCode),
        ])

        menuBarController.setup()

        AppExclusionManager.shared.onAppChanged = { bundleID in
            NSLog("Pankey: app changed → \(bundleID ?? "unknown")")
        }

        requestAccessibilityAndStart()
    }

    // MARK: - Accessibility permission

    /// Request Accessibility permission (required for CGEventTap).
    /// Shows the system prompt exactly once, then polls silently until granted.
    private func requestAccessibilityAndStart() {
        // Show the system prompt once — passing prompt:true repeatedly re-triggers the dialog
        let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(promptOptions)
        pollForAccessibility()
    }

    /// Silently re-check every second until Accessibility is granted, then start the tap.
    private func pollForAccessibility() {
        if AXIsProcessTrusted() {
            keyboardTap.start()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.pollForAccessibility()
            }
        }
    }

    // Standalone menu-bar app — never quit when windows close
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { false }
}
