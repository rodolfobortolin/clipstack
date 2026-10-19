import AppKit
import SwiftUI

/// A short confirmation near the bottom of the screen, like the system's own
/// "Copied" bezels. It never takes focus or clicks.
final class HUD {
    private static let shared = HUD()

    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    static func show(_ text: String, symbol: String) {
        shared.show(text, symbol: symbol)
    }

    private func show(_ text: String, symbol: String) {
        let panel = self.panel ?? makePanel()
        self.panel = panel

        let hosting = NSHostingView(rootView: HUDView(text: text, symbol: symbol))
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hosting
        panel.setContentSize(size)

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.minY + 90))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }

        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            await NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                panel.animator().alphaValue = 0
            }
            guard !Task.isCancelled else { return }
            panel.orderOut(nil)
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return panel
    }
}

private struct HUDView: View {
    let text: String
    let symbol: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .modifier(PanelChrome(material: AppSettings.shared.panelMaterial, cornerRadius: 22))
        .background(OuterShadow(cornerRadius: 22, radius: 12, y: 5, opacity: 0.3))
        .padding(28)
        .fixedSize()
    }
}
