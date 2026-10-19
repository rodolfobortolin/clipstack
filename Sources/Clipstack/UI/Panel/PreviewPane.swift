import SwiftUI

struct PreviewPane: View {
    let row: PanelRow?

    var body: some View {
        switch row {
        case .clip(let item):
            ClipPreview(item: item)
        case .snippet(let snippet):
            SnippetPreview(snippet: snippet)
        case nil:
            ContentUnavailableView("No Selection", systemImage: "eye.slash")
        }
    }
}

private struct ClipPreview: View {
    let item: ClipItem

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider().opacity(0.5)
            MetadataGrid(rows: metadata)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .image:
            if let image = ImageCache.shared.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                    .padding(20)
            }
        case .color:
            ColorPreview(hex: item.text ?? "")
        case .file:
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(item.filePathList, id: \.self) { path in
                        HStack(spacing: 10) {
                            Image(nsImage: AppIconCache.shared.fileIcon(for: path))
                                .resizable()
                                .frame(width: 34, height: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text((path as NSString).lastPathComponent)
                                    .font(.system(size: 13, weight: .medium))
                                Text((path as NSString).deletingLastPathComponent)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            }
        case .link:
            LinkPreview(link: (item.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        case .text, .richText:
            ScrollView {
                Text(previewText)
                    .font(.system(size: 13))
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(18)
            }
        }
    }

    private var previewText: String {
        let text = item.text ?? ""
        return text.count > 20_000 ? String(text.prefix(20_000)) + "\n…" : text
    }

    private var metadata: [(String, String)] {
        var rows: [(String, String)] = [
            (String(localized: "Source"), item.sourceAppName ?? String(localized: "Unknown")),
            (String(localized: "Copied"), Formatters.dateTime.string(from: item.createdAt)),
            (String(localized: "Type"), item.kind.title),
        ]
        switch item.kind {
        case .image:
            rows.append((String(localized: "Size"), "\(item.imageWidth) × \(item.imageHeight) px"))
        case .file:
            let count = item.filePathList.count
            rows.append((String(localized: "Items"), count == 1 ? String(localized: "1 file") : String(localized: "\(count) files")))
        case .text, .richText:
            let text = item.text ?? ""
            let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
            rows.append((String(localized: "Size"), String(localized: "\(text.count) characters · \(words) words")))
        case .link, .color:
            break
        }
        if item.useCount > 0 {
            rows.append((String(localized: "Used"), item.useCount == 1 ? String(localized: "once") : String(localized: "\(item.useCount) times")))
        }
        return rows
    }
}

private struct SnippetPreview: View {
    let snippet: Snippet

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(snippet.body)
                        .font(.system(size: 13, design: .monospaced))
                        .textSelection(.enabled)
                    if snippet.body.contains("{") {
                        Divider()
                        Text("Will paste")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(SnippetExpander.expand(snippet.body, clipboard: NSPasteboard.general.string(forType: .string)))
                            .font(.system(size: 13))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(18)
            }
            Divider().opacity(0.5)
            MetadataGrid(rows: [
                (String(localized: "Type"), String(localized: "Snippet")),
                (String(localized: "Created"), Formatters.dateTime.string(from: snippet.createdAt)),
            ])
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

private struct ColorPreview: View {
    let hex: String

    var body: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hex: hex) ?? .gray)
                .frame(width: 140, height: 140)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.primary.opacity(0.12)))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            Text(hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .textSelection(.enabled)
            if let components = HexColor.components(hex) {
                Text("RGB \(Int(components.r * 255)), \(Int(components.g * 255)), \(Int(components.b * 255))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LinkPreview: View {
    let link: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "link")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tint)
            Text(link)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(6)
                .textSelection(.enabled)
            if let host = URL(string: link)?.host() {
                Text(host)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            if let url = URL(string: link) {
                Button("Open") {
                    PanelController.shared.close()
                    NSWorkspace.shared.open(url)
                }
                .controlSize(.regular)
            }
        }
        .padding(24)
    }
}

private struct MetadataGrid: View {
    let rows: [(String, String)]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
            ForEach(rows, id: \.0) { label, value in
                GridRow {
                    Text(label)
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    Text(value)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .font(.system(size: 11.5))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
