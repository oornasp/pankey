// AppDelegate.swift — IMKServer bootstrap for Pankey input method
import Cocoa
import InputMethodKit

@objc class AppDelegate: NSObject, NSApplicationDelegate {

    // MUST be stored properties — local vars are deallocated immediately
    var server: IMKServer?
    private let menuBarController = MenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register defaults so UserDefaults.bool(forKey:) returns correct value before first write
        UserDefaults.standard.register(defaults: [
            "isVietnameseEnabled": true,
            "inputMethod": "telex",
        ])

        guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String else {
            NSLog("Pankey ERROR: InputMethodConnectionName missing from Info.plist")
            NSApplication.shared.terminate(nil)
            return
        }

        server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
        NSLog("Pankey: IMKServer initialized — \(connectionName)")

        menuBarController.setup()

        // App exclusion: reset engine on app switch (InputController handles its own reset
        // via activateServer/deactivateServer; this callback is available for future use)
        AppExclusionManager.shared.onAppChanged = { bundleID in
            NSLog("Pankey: app changed → \(bundleID ?? "unknown")")
        }
    }

    // Input methods are background agents — never exit when windows close
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        return false
    }
}
