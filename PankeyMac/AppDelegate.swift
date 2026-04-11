import Cocoa
import InputMethodKit

@objc class AppDelegate: NSObject, NSApplicationDelegate {
    // IMKServer must be a stored property — local var is deallocated immediately
    var server: IMKServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("Pankey: applicationDidFinishLaunching — stub (Phase 3 will initialise IMKServer)")
    }
}
