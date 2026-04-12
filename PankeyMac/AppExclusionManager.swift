// AppExclusionManager.swift — per-app exclusion list: storage, lookup, and active-app observation
import AppKit

final class AppExclusionManager {
    static let shared = AppExclusionManager()

    private let defaultsKey = "excludedBundleIDs"
    private var exclusionSet: Set<String> = []
    private var appChangeObserver: NSObjectProtocol?

    /// Callback invoked when the frontmost app changes (used by InputController to reset engine)
    var onAppChanged: ((String?) -> Void)?

    private init() {
        loadFromDefaults()
        observeAppChanges()
    }

    deinit {
        if let observer = appChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// O(1) check — called on every key event
    func isCurrentAppExcluded() -> Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false   // Cannot determine — allow input by default
        }
        return exclusionSet.contains(bundleID)
    }

    func excludedBundleIDs() -> [String] {
        Array(exclusionSet).sorted()
    }

    func add(bundleID: String) {
        exclusionSet.insert(bundleID)
        saveToDefaults()
        NSLog("Pankey: excluded app added — \(bundleID)")
    }

    func remove(bundleID: String) {
        exclusionSet.remove(bundleID)
        saveToDefaults()
        NSLog("Pankey: excluded app removed — \(bundleID)")
    }

    func contains(_ bundleID: String) -> Bool {
        exclusionSet.contains(bundleID)
    }

    // MARK: - Convenience helpers for Settings UI (Phase 5)

    /// Adds the currently frontmost app and returns its bundle ID, or nil if unavailable
    @discardableResult
    func addFrontmostApp() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier else { return nil }
        add(bundleID: bundleID)
        return bundleID
    }

    /// Returns (name, bundleID) of the frontmost app for display in Settings UI
    func frontmostAppInfo() -> (name: String, bundleID: String)? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier else { return nil }
        return (name: app.localizedName ?? bundleID, bundleID: bundleID)
    }

    // MARK: - Persistence

    private func loadFromDefaults() {
        if let saved = UserDefaults.standard.array(forKey: defaultsKey) as? [String], !saved.isEmpty {
            exclusionSet = Set(saved)
        } else {
            // Pre-populate default developer tools on first launch
            exclusionSet = Self.defaultExcludedApps
            saveToDefaults()
        }
        NSLog("Pankey: loaded \(exclusionSet.count) excluded apps")
    }

    private func saveToDefaults() {
        UserDefaults.standard.set(Array(exclusionSet), forKey: defaultsKey)
    }

    // MARK: - App change observation

    private func observeAppChanges() {
        appChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let bundleID = (notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication)?.bundleIdentifier
            self?.onAppChanged?(bundleID)
        }
    }

    // MARK: - Default exclusion list

    /// Common developer tools that should not receive Vietnamese input by default
    static let defaultExcludedApps: Set<String> = [
        "com.apple.Terminal",
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.googlecode.iterm2",
        "com.sublimetext.4",
        "com.jetbrains.intellij",
        "net.kovidgoyal.kitty",
    ]
}
