import SwiftUI

struct PanelRowView: View {
    let row: PanelRow
    let index: Int
    let isSelected: Bool
    let density: RowDensity

    var body: some View {
        HStack(spacing: 10) {
            RowIcon(row: row, size: density.iconSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                if density == .comfortable {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            if isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .rotationEffect(.degrees(45))
                    .foregroundStyle(.secondary)
            }
            if index < 10 {
                Text("⌘\((index + 1) % 10)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: density.rowHeight)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.tint.opacity(0.2))
            }
        }
        .contentShape(Rectangle())
    }

    private var title: String {
        switch row {
        case .clip(let item): item.displayTitle
        case .snippet(let snippet): snippet.displayTitle
        }
    }

    private var subtitle: String {
        switch row {
        case .clip(let item):
            let source = item.sourceAppName ?? item.kind.title
            return "\(source) · \(Formatters.relativeString(item.createdAt))"
        case .snippet(let snippet):
            return String(localized: "Snippet") + " · " + ClipItem.firstLine(of: snippet.body)
        }
    }

    private var isPinned: Bool {
        if case .clip(let item) = row { return item.isPinned }
        return false
    }
}

struct RowIcon: View {
    let row: PanelRow
    let size: CGFloat

    var body: some View {
        switch row {
        case .snippet:
            SymbolTile(symbol: "text.quote", size: size)
        case .clip(let item):
            clipIcon(item)
        }
    }

    @ViewBuilder
    private func clipIcon(_ item: ClipItem) -> some View {
        switch item.kind {
        case .image:
            if let image = ImageCache.shared.thumbnail(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous).strokeBorder(.primary.opacity(0.1)))
            } else {
                SymbolTile(symbol: "photo", size: size)
            }
        case .color:
            Circle()
                .fill(Color(hex: item.text) ?? .gray)
                .frame(width: size * 0.8, height: size * 0.8)
                .overlay(Circle().strokeBorder(.primary.opacity(0.15)))
                .frame(width: size, height: size)
        case .file:
            Image(nsImage: AppIconCache.shared.fileIcon(for: item.filePathList.first))
                .resizable()
                .frame(width: size, height: size)
        case .text, .richText, .link:
            if let icon = AppIconCache.shared.icon(for: item.sourceBundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: size, height: size)
                    .overlay(alignment: .bottomTrailing) {
                        if item.kind == .link {
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: size * 0.42))
                                .foregroundStyle(.white, .tint)
                                .offset(x: 2, y: 2)
                        }
                    }
            } else {
                SymbolTile(symbol: item.kind == .link ? "link" : "doc.text", size: size)
            }
        }
    }
}

struct SymbolTile: View {
    let symbol: String
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(.tint.opacity(0.16))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(.tint)
            }
    }
}
