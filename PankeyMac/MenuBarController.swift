// MenuBarController.swift — NSStatusItem setup with pixel "VI"/"EN" icon and dropdown menu
import Cocoa

final class MenuBarController {
    private var statusItem: NSStatusItem?
    private let settingsController = SettingsWindowController()
    private var defaultsObserver: NSObjectProtocol?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Register default so first launch reads correctly
        UserDefaults.standard.register(defaults: ["isVietnameseEnabled": true])
        updateIcon()
        buildMenu()
        observeDefaults()
    }

    // MARK: - Icon

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let isVietnamese = UserDefaults.standard.bool(forKey: "isVietnameseEnabled")
        let title = isVietnamese ? "VI" : "EN"
        let font = NSFont(name: "Press Start 2P", size: 9)
            ?? NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: font,
                .foregroundColor: NSColor(PixelTheme.accent)
            ]
        )
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Toggle VI/EN", action: #selector(toggleInputMode), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        for (title, method) in [("Telex", "telex"), ("VNI", "vni")] {
            let item = NSMenuItem(title: title, action: #selector(selectMethod(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = method
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Pankey",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleInputMode() {
        let current = UserDefaults.standard.bool(forKey: "isVietnameseEnabled")
        UserDefaults.standard.set(!current, forKey: "isVietnameseEnabled")
        // updateIcon() is called via the defaults observer
    }

    @objc private func selectMethod(_ sender: NSMenuItem) {
        guard let method = sender.representedObject as? String else { return }
        UserDefaults.standard.set(method, forKey: "inputMethod")
    }

    @objc private func openSettings() {
        settingsController.showSettings()
    }

    // MARK: - Observe UserDefaults to keep icon in sync

    private func observeDefaults() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateIcon()
        }
    }

    deinit {
        if let obs = defaultsObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}
