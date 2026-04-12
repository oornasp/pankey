// SettingsWindowController.swift — NSWindowController wrapping SwiftUI SettingsView in an NSPanel
import Cocoa
import SwiftUI

final class SettingsWindowController: NSWindowController {
    convenience init() {
        let hostingController = NSHostingController(rootView: SettingsView())
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Pankey Settings"
        panel.contentViewController = hostingController
        panel.center()
        // Prevent deallocation when the window closes so it can be re-opened
        panel.isReleasedWhenClosed = false
        self.init(window: panel)
    }

    func showSettings() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
