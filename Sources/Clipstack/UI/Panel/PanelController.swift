import AppKit
import SwiftUI

enum PanelMetrics {
    static let size = CGSize(width: 780, height: 500)
    static let cornerRadius: CGFloat = 24
    /// Transparent room around the panel for its shadow and the glass edge,
    /// which the window bounds would otherwise cut off at the corners.
    static let margin: CGFloat = 40
    static var windowSize: CGSize {
        CGSize(width: size.width + margin * 2, height: size.height + margin * 2)
    }
}

/// A panel that takes keyboard focus without activating Clipstack, the way
/// Spotlight does: the app you were in stays in front, ready for the paste.
final class FloatingPanel: NSPanel {
    override init(
        contentRect: NSRect, styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: backingStoreType, defer: flag
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        // The window shadow is computed when the window appears, before SwiftUI
        // draws, so it comes out rectangular. The panel draws its own instead.
        hasShadow = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PanelController: NSObject, NSWindowDelegate {
    static let shared = PanelController()

    let model = PanelModel()
    private var panel: FloatingPanel?
    private var keyMonitor: Any?
    private var lastClosed = Date.distantPast

    var isVisible: Bool { panel?.isVisible == true }

    func toggle(anchor: NSRect? = nil) {
        if isVisible {
            close()
        } else if Date().timeIntervalSince(lastClosed) > 0.25 {
            // Clicking the menu bar icon closes the panel first (it loses focus);
            // without this guard the same click would reopen it.
            show(anchor: anchor)
        }
    }

    func show(anchor: NSRect? = nil) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        model.prepareForShow()
        position(panel, anchor: anchor)
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func close() {
        guard let panel, panel.isVisible else { return }
        removeKeyMonitor()
        model.editing = nil
        panel.orderOut(nil)
        lastClosed = Date()
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: PanelMetrics.windowSize),
            styleMask: [], backing: .buffered, defer: false
        )
        let hosting = NSHostingView(rootView: PanelView(model: model))
        hosting.frame = NSRect(origin: .zero, size: PanelMetrics.windowSize)
        panel.contentView = hosting
        panel.setContentSize(PanelMetrics.windowSize)
        panel.delegate = self
        return panel
    }

    /// Places the visible panel; the window around it is `margin` larger on every side.
    private func position(_ panel: NSPanel, anchor: NSRect?) {
        let size = PanelMetrics.size
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        var origin: NSPoint
        if let anchor {
            origin = NSPoint(x: anchor.midX - size.width / 2, y: anchor.minY - size.height - 6)
        } else if AppSettings.shared.panelPosition == .cursor {
            origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height - 14)
            if origin.y < visible.minY { origin.y = mouse.y + 14 }
        } else {
            // Like Spotlight: centered, in the upper part of the screen.
            origin = NSPoint(x: visible.midX - size.width / 2, y: visible.maxY - visible.height * 0.16 - size.height)
        }
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        panel.setFrameOrigin(NSPoint(x: origin.x - PanelMetrics.margin, y: origin.y - PanelMetrics.margin))
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel, event.window === panel else { return event }
            return self.model.handleKey(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}
