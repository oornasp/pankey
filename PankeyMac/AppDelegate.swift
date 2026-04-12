// AppDelegate.swift — IMKServer bootstrap for Pankey input method
import Cocoa
import InputMethodKit

@objc class AppDelegate: NSObject, NSApplicationDelegate {

    // MUST be a stored property — local var is deallocated immediately and breaks all key handling
    var server: IMKServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String else {
            NSLog("Pankey ERROR: InputMethodConnectionName missing from Info.plist")
            NSApplication.shared.terminate(nil)
            return
        }

        server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
        NSLog("Pankey: IMKServer initialized — \(connectionName)")

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
