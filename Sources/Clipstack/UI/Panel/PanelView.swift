import SwiftUI

struct PanelView: View {
    @Bindable var model: PanelModel
    @FocusState private var searchFocused: Bool

    private var settings: AppSettings { .shared }

    var body: some View {
        let rows = model.rows
        let selected = rows.indices.contains(model.selection) ? rows[model.selection] : nil

        VStack(spacing: 0) {
            searchBar
            filterBar
            Divider().opacity(0.5)
            HStack(spacing: 0) {
                list(rows)
                    .frame(width: model.showPreview ? 340 : nil)
                    .frame(maxWidth: model.showPreview ? nil : .infinity)
                if model.showPreview {
                    Divider().opacity(0.5)
                    PreviewPane(row: selected)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
            Divider().opacity(0.5)
            footer(count: rows.count)
        }
        .frame(width: PanelMetrics.size.width, height: PanelMetrics.size.height)
        .modifier(PanelChrome(material: settings.panelMaterial, cornerRadius: PanelMetrics.cornerRadius))
        .overlay {
            if model.editing != nil {
                EditOverlay(model: model)
                    .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.cornerRadius, style: .continuous))
            }
        }
        .background(OuterShadow(cornerRadius: PanelMetrics.cornerRadius, radius: 26, y: 14, opacity: 0.38))
        .padding(PanelMetrics.margin)
        .tint(settings.accent.color)
        .onAppear { searchFocused = true }
        .onChange(of: model.focusToken) { searchFocused = true }
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search history", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 21))
                .focused($searchFocused)
            if !settings.isRecordingActive {
                Label("Paused", systemImage: "pause.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(.orange)
                    .background(.orange.opacity(0.18), in: Capsule())
            }
            Button(action: model.openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings (⌘,)")
        }
        .padding(.horizontal, 20)
        .frame(height: 58)
    }

    private var filterBar: some View {
        HStack(spacing: 4) {
            ForEach(PanelFilter.allCases) { filter in
                FilterChip(filter: filter, isSelected: model.filter == filter) {
                    model.filter = filter
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    // MARK: List

    private func list(_ rows: [PanelRow]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        PanelRowView(row: row, index: index, isSelected: index == model.selection, density: settings.density)
                            .id(row.id)
                            .onTapGesture(count: 2) { model.activate(at: index, mode: .paste) }
                            .onTapGesture {
                                if settings.singleClickPastes {
                                    model.activate(at: index, mode: .paste)
                                } else {
                                    model.selection = index
                                }
                            }
                            .contextMenu { RowContextMenu(model: model, row: row, index: index) }
                    }
                }
                .padding(8)
            }
            .onChange(of: model.selection) {
                guard rows.indices.contains(model.selection) else { return }
                proxy.scrollTo(rows[model.selection].id)
            }
            .overlay {
                if rows.isEmpty { emptyState }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !model.query.isEmpty {
            ContentUnavailableView.search(text: model.query)
        } else if model.filter == .snippets {
            ContentUnavailableView(
                "No Snippets", systemImage: "text.quote",
                description: Text("Press ⌘S on an item to keep it, or create one in Settings.")
            )
        } else if model.filter == .pinned {
            ContentUnavailableView(
                "Nothing Pinned", systemImage: "pin",
                description: Text("Pin what you use all the time with ⌘P.")
            )
        } else {
            ContentUnavailableView(
                "Nothing Here Yet", systemImage: "doc.on.clipboard",
                description: Text("Copy something and it shows up here.")
            )
        }
    }

    // MARK: Footer

    private func footer(count: Int) -> some View {
        HStack(spacing: 14) {
            Text(count == 1 ? String(localized: "1 item") : String(localized: "\(count) items"))
                .foregroundStyle(.secondary)
            Spacer()
            KeyHint(keys: "↩", label: "Paste")
            KeyHint(keys: "⇧↩", label: "Plain Text")
            KeyHint(keys: "⌘P", label: "Pin")
            KeyHint(keys: "⌘E", label: "Edit")
            KeyHint(keys: "⌘Y", label: "Preview")
        }
        .font(.system(size: 11))
        .padding(.horizontal, 18)
        .frame(height: 32)
    }
}

private struct FilterChip: View {
    let filter: PanelFilter
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(filter.title, systemImage: filter.symbol)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .background {
                    Capsule().fill(
                        isSelected ? AnyShapeStyle(.tint.opacity(0.18))
                            : isHovering ? AnyShapeStyle(.primary.opacity(0.06)) : AnyShapeStyle(.clear)
                    )
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct RowContextMenu: View {
    let model: PanelModel
    let row: PanelRow
    let index: Int

    var body: some View {
        Button("Paste") { model.activate(at: index, mode: .paste) }
        if row.isTextual {
            Button("Paste as Plain Text") { model.activate(at: index, mode: .plainText) }
        }
        Button("Copy") { model.activate(at: index, mode: .copyOnly) }
        Divider()
        if case .clip(let item) = row {
            if item.isPinned {
                Button("Unpin") { model.togglePin(row) }
            } else {
                Button("Pin") { model.togglePin(row) }
            }
            if item.kind.isTextual {
                Button("Edit…") {
                    model.selection = index
                    model.beginEdit(row)
                }
            } else {
                Button("Rename…") {
                    model.selection = index
                    model.beginEdit(row)
                }
            }
            if item.kind.isTextual {
                Button("Save as Snippet") { model.saveAsSnippet(row) }
            }
            if item.kind == .link, let text = item.text, let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                Button("Open Link") {
                    PanelController.shared.close()
                    NSWorkspace.shared.open(url)
                }
            }
            if item.kind == .file, !item.fileURLs.isEmpty {
                Button("Show in Finder") {
                    PanelController.shared.close()
                    NSWorkspace.shared.activateFileViewerSelecting(item.fileURLs)
                }
            }
        } else {
            Button("Edit…") {
                model.selection = index
                model.beginEdit(row)
            }
        }
        Divider()
        Button("Delete", role: .destructive) { model.delete(row) }
    }
}
