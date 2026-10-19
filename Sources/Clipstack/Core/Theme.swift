import AppKit
import SwiftUI

nonisolated enum PanelPosition: String, CaseIterable, Identifiable {
    case center, cursor
    var id: String { rawValue }
    var title: String {
        switch self {
        case .center: String(localized: "Center of the screen")
        case .cursor: String(localized: "Next to the pointer")
        }
    }
}

nonisolated enum PanelMaterial: String, CaseIterable, Identifiable {
    case glass, translucent, solid
    var id: String { rawValue }
    var title: String {
        switch self {
        case .glass: String(localized: "Glass")
        case .translucent: String(localized: "Translucent")
        case .solid: String(localized: "Solid")
        }
    }
}

nonisolated enum RowDensity: String, CaseIterable, Identifiable {
    case comfortable, compact
    var id: String { rawValue }
    var title: String {
        switch self {
        case .comfortable: String(localized: "Comfortable")
        case .compact: String(localized: "Compact")
        }
    }
    var rowHeight: CGFloat { self == .comfortable ? 46 : 32 }
    var iconSize: CGFloat { self == .comfortable ? 28 : 20 }
}

nonisolated enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: String(localized: "Automatic")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }
}

extension AppearanceMode {
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

/// The accent colors macOS offers in Appearance settings, plus the system one.
nonisolated enum AccentChoice: String, CaseIterable, Identifiable {
    case multicolor, blue, purple, pink, red, orange, yellow, green, graphite
    var id: String { rawValue }
    var title: String {
        switch self {
        case .multicolor: String(localized: "System accent")
        case .blue: String(localized: "Blue")
        case .purple: String(localized: "Purple")
        case .pink: String(localized: "Pink")
        case .red: String(localized: "Red")
        case .orange: String(localized: "Orange")
        case .yellow: String(localized: "Yellow")
        case .green: String(localized: "Green")
        case .graphite: String(localized: "Graphite")
        }
    }
}

extension AccentChoice {
    var color: Color {
        switch self {
        case .multicolor: .accentColor
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .graphite: .gray
        }
    }
}

extension Color {
    /// Parses `#RGB`, `#RRGGBB` and `#RRGGBBAA`.
    init?(hex: String?) {
        guard let components = HexColor.components(hex) else { return nil }
        self.init(.sRGB, red: components.r, green: components.g, blue: components.b, opacity: components.a)
    }
}

nonisolated enum HexColor {
    static func isHexColor(_ string: String) -> Bool {
        components(string) != nil
    }

    static func components(_ string: String?) -> (r: Double, g: Double, b: Double, a: Double)? {
        guard var hex = string?.trimmingCharacters(in: .whitespacesAndNewlines), hex.hasPrefix("#") else { return nil }
        hex.removeFirst()
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        guard hex.count == 6 || hex.count == 8,
              hex.allSatisfy(\.isHexDigit),
              let value = UInt64(hex, radix: 16)
        else { return nil }
        if hex.count == 8 {
            return (Double((value >> 24) & 0xFF) / 255, Double((value >> 16) & 0xFF) / 255,
                    Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
        }
        return (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255,
                Double(value & 0xFF) / 255, 1)
    }
}
