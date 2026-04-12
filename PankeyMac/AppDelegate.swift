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
        ])

        menuBarController.setup()

        AppExclusionManager.shared.onAppChanged = { bundleID in
            NSLog("Pankey: app changed → \(bundleID ?? "unknown")")
        }

        requestAccessibilityAndStart()
    }

    // MARK: - Accessibility permission

    /// Request Accessibility permission (required for CGEventTap).
    /// macOS shows a one-time system prompt; polls every second until granted.
    private func requestAccessibilityAndStart() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            keyboardTap.start()
        } else {
            // User has not granted yet — re-check after a short delay.
            // The system prompt is already shown; this loop handles the case where
            // the user grants permission in System Settings without relaunching the app.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.requestAccessibilityAndStart()
            }
        }
    }

    // Standalone menu-bar app — never quit when windows close
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { false }
}
