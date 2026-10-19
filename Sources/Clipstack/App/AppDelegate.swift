import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private let settings = AppSettings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings.applyAppearance()
        _ = ClipStore.shared
        ClipboardMonitor.shared.start()
        statusItem = StatusItemController()
        registerHotKeys()

        NotificationCenter.default.addObserver(
            self, selector: #selector(shortcutsChanged), name: .clipstackShortcutsChanged, object: nil
        )

        if !settings.hasLaunchedBefore {
            settings.hasLaunchedBefore = true
            SettingsWindowController.shared.show(tab: .general)
        }
    }

    /// Opening the app again from Finder or Spotlight while it runs shows the history.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        PanelController.shared.show()
        return false
    }

    @objc func openSettings(_ sender: Any?) {
        SettingsWindowController.shared.show()
    }

    @objc private func shortcutsChanged() {
        registerHotKeys()
    }

    private func registerHotKeys() {
        HotKeyCenter.shared.register(.panel, shortcut: settings.panelShortcut) {
            PanelController.shared.toggle()
        }
        HotKeyCenter.shared.register(.cursorMenu, shortcut: settings.menuShortcut) {
            CursorMenuController.shared.show()
        }
    }
}
