import AppKit
import SwiftUI

/// The panel's background: Liquid Glass on macOS 26, a blurred material before it.
struct PanelChrome: ViewModifier {
    let material: PanelMaterial
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch material {
        case .glass:
            if #available(macOS 26.0, *) {
                content
                    .clipShape(shape)
                    .glassEffect(.regular, in: shape)
            } else {
                blurred(content, shape: shape, material: .popover)
            }
        case .translucent:
            blurred(content, shape: shape, material: .hudWindow)
        case .solid:
            content
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(shape)
                .overlay(shape.strokeBorder(.separator))
        }
    }

    private func blurred(_ content: Content, shape: RoundedRectangle, material: NSVisualEffectView.Material) -> some View {
        content
            .background(VisualEffectView(material: material))
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.12)))
    }
}

/// A soft shadow drawn only outside a rounded shape, so it never darkens
/// the translucent glass in front of it.
struct OuterShadow: View {
    let cornerRadius: CGFloat
    var radius: CGFloat = 24
    var y: CGFloat = 12
    var opacity: Double = 0.35

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(.black.opacity(opacity))
            .blur(radius: radius)
            .offset(y: y)
            .mask {
                Rectangle()
                    .padding(-radius * 4)
                    .overlay(shape.blendMode(.destinationOut))
                    .compositingGroup()
            }
            .allowsHitTesting(false)
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

/// A keyboard shortcut drawn as a key cap, followed by what it does.
struct KeyHint: View {
    let keys: String
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: 5) {
            Text(keys)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}
