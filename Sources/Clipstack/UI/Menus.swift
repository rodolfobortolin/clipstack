import AppKit

/// Keeps a menu item's closure alive; `NSMenuItem.target` is weak.
final class MenuAction: NSObject {
    private let handler: () -> Void

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func fire() {
        handler()
    }
}

extension NSMenuItem {
    /// A menu item that runs a closure.
    convenience init(title: String, keyEquivalent: String = "", handler: @escaping () -> Void) {
        let action = MenuAction(handler)
        self.init(title: title, action: #selector(MenuAction.fire), keyEquivalent: keyEquivalent)
        target = action
        representedObject = action
    }
}

/// The compact menu the second shortcut opens wherever the mouse is.
final class CursorMenuController {
    static let shared = CursorMenuController()

    private static let maxRecent = 12
    private static let maxTitleLength = 54

    func show() {
        PanelController.shared.close()
        let target = NSWorkspace.shared.frontmostApplication
        let store = ClipStore.shared
        let menu = NSMenu()
        menu.autoenablesItems = false

        let pinned = store.clips.filter(\.isPinned)
        let recent = store.clips.filter { !$0.isPinned }.prefix(Self.maxRecent)
        var position = 0

        func add(_ item: ClipItem) {
            let menuItem = NSMenuItem(title: Self.truncate(item.displayTitle)) {
                Paster.shared.perform(item, mode: .paste, target: target)
            }
            menuItem.image = Self.icon(for: item)
            if position < 10 {
                menuItem.keyEquivalent = "\((position + 1) % 10)"
                menuItem.keyEquivalentModifierMask = []
            }
            position += 1
            menu.addItem(menuItem)
        }

        if !pinned.isEmpty {
            menu.addItem(.sectionHeader(title: String(localized: "Pinned")))
            pinned.forEach(add)
        }
        if !recent.isEmpty {
            menu.addItem(.sectionHeader(title: String(localized: "Recent")))
            recent.forEach(add)
        }
        if pinned.isEmpty, recent.isEmpty {
            let empty = NSMenuItem(title: String(localized: "Nothing copied yet"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }

        if !store.snippets.isEmpty {
            menu.addItem(.separator())
            let snippetsItem = NSMenuItem(title: String(localized: "Snippets"), action: nil, keyEquivalent: "")
            snippetsItem.image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: nil)
            let submenu = NSMenu()
            for snippet in store.snippets {
                submenu.addItem(NSMenuItem(title: Self.truncate(snippet.displayTitle)) {
                    Paster.shared.perform(snippet: snippet, mode: .paste, target: target)
                })
            }
            snippetsItem.submenu = submenu
            menu.addItem(snippetsItem)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Open History…")) { PanelController.shared.show() })

        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private static func truncate(_ title: String) -> String {
        title.count > maxTitleLength ? String(title.prefix(maxTitleLength - 1)) + "…" : title
    }

    private static func icon(for item: ClipItem) -> NSImage? {
        let image: NSImage?
        switch item.kind {
        case .image: image = ImageCache.shared.thumbnail(for: item)
        case .file: image = AppIconCache.shared.fileIcon(for: item.filePathList.first)
        case .color: image = swatch(item.text)
        case .text, .richText, .link: image = AppIconCache.shared.icon(for: item.sourceBundleID)
        }
        guard let image else { return nil }
        let sized = image.copy() as? NSImage
        sized?.size = NSSize(width: 16, height: 16)
        return sized
    }

    private static func swatch(_ hex: String?) -> NSImage? {
        guard let c = HexColor.components(hex) else { return nil }
        return NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: c.a).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 1.5)).fill()
            return true
        }
    }
}

/// The menu bar icon: a click opens the history, a right-click the menu.
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let settings = AppSettings.shared

    override init() {
        super.init()
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateIcon()
        NotificationCenter.default.addObserver(self, selector: #selector(updateIcon), name: .clipstackPauseChanged, object: nil)
    }

    @objc private func updateIcon() {
        let symbol = settings.isRecordingActive ? "doc.on.clipboard" : "pause.circle"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Clipstack")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = settings.isRecordingActive ? "Clipstack" : String(localized: "Clipstack — recording paused")
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
            || event?.modifierFlags.contains(.option) == true
        if wantsMenu {
            showMenu()
        } else {
            let frame = sender.window.map { $0.convertToScreen(sender.convert(sender.bounds, to: nil)) }
            PanelController.shared.toggle(anchor: frame)
        }
    }

    private func showMenu() {
        statusItem.menu = makeMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let open = NSMenuItem(title: String(localized: "Open History")) { PanelController.shared.show() }
        if let equivalent = settings.panelShortcut?.menuKeyEquivalent {
            open.keyEquivalent = equivalent.key
            open.keyEquivalentModifierMask = equivalent.modifiers
        }
        menu.addItem(open)
        menu.addItem(.separator())

        if settings.isRecordingActive {
            let pause = NSMenuItem(title: String(localized: "Pause Recording"), action: nil, keyEquivalent: "")
            let options = NSMenu()
            options.addItem(NSMenuItem(title: String(localized: "For 15 Minutes")) { self.settings.pause(minutes: 15) })
            options.addItem(NSMenuItem(title: String(localized: "For 1 Hour")) { self.settings.pause(minutes: 60) })
            options.addItem(NSMenuItem(title: String(localized: "Until I Resume")) { self.settings.pause(minutes: nil) })
            pause.submenu = options
            menu.addItem(pause)
        } else {
            var title = String(localized: "Resume Recording")
            if let until = settings.pausedUntil {
                let time = Formatters.time.string(from: until)
                title = String(localized: "Resume Recording (paused until \(time))")
            }
            menu.addItem(NSMenuItem(title: title) { self.settings.resume() })
        }
        menu.addItem(NSMenuItem(title: String(localized: "Clear History…")) { Self.confirmClearHistory() })

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Settings…"), keyEquivalent: ",") { SettingsWindowController.shared.show() })
        menu.addItem(NSMenuItem(title: String(localized: "About Clipstack")) { SettingsWindowController.shared.show(tab: .about) })
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Quit Clipstack"), keyEquivalent: "q") { NSApp.terminate(nil) })
        return menu
    }

    static func confirmClearHistory() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = String(localized: "Clear the history?")
        alert.informativeText = String(localized: "All unpinned items will be deleted. Pinned items and snippets are kept.")
        alert.addButton(withTitle: String(localized: "Clear"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn {
            ClipStore.shared.clearHistory()
        }
    }
}
