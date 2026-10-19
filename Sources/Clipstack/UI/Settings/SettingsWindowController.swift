import AppKit
import SwiftUI

enum SettingsTab: Int, CaseIterable {
    case general, shortcuts, privacy, appearance, snippets, about
}

/// A classic macOS preferences window: toolbar tabs, the window resizing to
/// fit each one.
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private let tabs = SettingsTabViewController()

    private init() {
        tabs.tabStyle = .toolbar
        tabs.add(GeneralSettingsView(), title: String(localized: "General"), symbol: "gearshape")
        tabs.add(ShortcutsSettingsView(), title: String(localized: "Shortcuts"), symbol: "keyboard")
        tabs.add(PrivacySettingsView(), title: String(localized: "Privacy"), symbol: "hand.raised")
        tabs.add(AppearanceSettingsView(), title: String(localized: "Appearance"), symbol: "paintpalette")
        tabs.add(SnippetsSettingsView(), title: String(localized: "Snippets"), symbol: "text.quote")
        tabs.add(AboutView(), title: String(localized: "About"), symbol: "info.circle")

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.title = String(localized: "General")
        super.init(window: window)
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(tab: SettingsTab? = nil) {
        if let tab { tabs.selectedTabViewItemIndex = tab.rawValue }
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

final class SettingsTabViewController: NSTabViewController {
    func add<Content: View>(_ view: Content, title: String, symbol: String) {
        let hosting = NSHostingController(rootView: Themed { view })
        hosting.sizingOptions = [.preferredContentSize]
        hosting.title = title
        let item = NSTabViewItem(viewController: hosting)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        addTabViewItem(item)
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        if let label = tabViewItem?.label { view.window?.title = label }
    }
}

/// Applies the chosen accent color to a settings tab.
struct Themed<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content.tint(AppSettings.shared.accent.color)
    }
}
