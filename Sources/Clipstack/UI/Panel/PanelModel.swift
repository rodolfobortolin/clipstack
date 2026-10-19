import AppKit
import Carbon.HIToolbox
import Observation

nonisolated enum PanelFilter: String, CaseIterable, Identifiable {
    case all, pinned, text, links, images, files, snippets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .pinned: String(localized: "Pinned")
        case .text: String(localized: "Text")
        case .links: String(localized: "Links")
        case .images: String(localized: "Images")
        case .files: String(localized: "Files")
        case .snippets: String(localized: "Snippets")
        }
    }

    var symbol: String {
        switch self {
        case .all: "tray.full"
        case .pinned: "pin"
        case .text: "text.alignleft"
        case .links: "link"
        case .images: "photo"
        case .files: "doc"
        case .snippets: "text.quote"
        }
    }
}

enum PanelRow: Identifiable {
    case clip(ClipItem)
    case snippet(Snippet)

    var id: String {
        switch self {
        case .clip(let item): "c-" + item.id.uuidString
        case .snippet(let snippet): "s-" + snippet.id.uuidString
        }
    }

    var isTextual: Bool {
        switch self {
        case .clip(let item): item.kind.isTextual
        case .snippet: true
        }
    }
}

struct EditDraft {
    var rowID: String
    var title: String
    var body: String
    var canEditBody: Bool
}

/// State and keyboard handling for the history panel.
@Observable
final class PanelModel {
    var query = "" {
        didSet { if query != oldValue { selection = 0 } }
    }
    var filter: PanelFilter = .all {
        didSet { if filter != oldValue { selection = 0 } }
    }
    var selection = 0
    var showPreview = true
    var editing: EditDraft?
    /// Bumped to move keyboard focus back to the search field.
    var focusToken = 0

    @ObservationIgnored private let store = ClipStore.shared
    @ObservationIgnored private let settings = AppSettings.shared

    var rows: [PanelRow] {
        let query = query.trimmingCharacters(in: .whitespaces)

        if filter == .snippets {
            return store.snippets
                .filter { query.isEmpty || $0.matches(query) }
                .map(PanelRow.snippet)
        }

        let pinned = store.clips.filter(\.isPinned)
            .sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
        let ordered = pinned + store.clips.filter { !$0.isPinned }

        var clips: [ClipItem]
        switch filter {
        case .all: clips = ordered
        case .pinned: clips = pinned
        case .text: clips = ordered.filter { [.text, .richText, .color].contains($0.kind) }
        case .links: clips = ordered.filter { $0.kind == .link }
        case .images: clips = ordered.filter { $0.kind == .image }
        case .files: clips = ordered.filter { $0.kind == .file }
        case .snippets: clips = []
        }
        if !query.isEmpty { clips = clips.filter { $0.matches(query) } }

        var rows = clips.map(PanelRow.clip)
        // Searching from "All" also finds snippets, after the history.
        if filter == .all, !query.isEmpty {
            rows += store.snippets.filter { $0.matches(query) }.map(PanelRow.snippet)
        }
        return rows
    }

    var selectedRow: PanelRow? {
        let rows = rows
        return rows.indices.contains(selection) ? rows[selection] : nil
    }

    func prepareForShow() {
        query = ""
        filter = .all
        selection = 0
        editing = nil
        showPreview = settings.showPreview
        focusToken += 1
    }

    // MARK: Actions

    func move(by delta: Int) {
        let count = rows.count
        guard count > 0 else { return }
        selection = min(max(selection + delta, 0), count - 1)
    }

    func cycleFilter(forward: Bool) {
        let all = PanelFilter.allCases
        guard let index = all.firstIndex(of: filter) else { return }
        filter = all[(index + (forward ? 1 : all.count - 1)) % all.count]
    }

    func activate(at index: Int? = nil, mode: PasteMode) {
        let rows = rows
        let index = index ?? selection
        guard rows.indices.contains(index) else { return }
        let row = rows[index]
        PanelController.shared.close()
        switch row {
        case .clip(let item): Paster.shared.perform(item, mode: mode)
        case .snippet(let snippet): Paster.shared.perform(snippet: snippet, mode: mode)
        }
    }

    func togglePin(_ row: PanelRow?) {
        guard case .clip(let item)? = row else { return }
        store.togglePin(item)
        if let index = rows.firstIndex(where: { $0.id == row?.id }) { selection = index }
    }

    func delete(_ row: PanelRow?) {
        switch row {
        case .clip(let item): store.delete(item)
        case .snippet(let snippet): store.delete(snippet)
        case nil: return
        }
        selection = min(selection, max(rows.count - 1, 0))
    }

    func beginEdit(_ row: PanelRow?) {
        switch row {
        case .clip(let item):
            editing = EditDraft(rowID: "c-" + item.id.uuidString, title: item.customTitle ?? "",
                                body: item.text ?? "", canEditBody: item.kind.isTextual)
        case .snippet(let snippet):
            editing = EditDraft(rowID: "s-" + snippet.id.uuidString, title: snippet.title,
                                body: snippet.body, canEditBody: true)
        case nil:
            return
        }
    }

    func commitEdit() {
        guard let draft = editing else { return }
        if let item = store.clips.first(where: { "c-" + $0.id.uuidString == draft.rowID }) {
            store.update(item, title: draft.title, text: draft.canEditBody ? draft.body : nil)
        } else if let snippet = store.snippets.first(where: { "s-" + $0.id.uuidString == draft.rowID }) {
            store.update(snippet, title: draft.title, body: draft.body)
        }
        editing = nil
        focusToken += 1
    }

    func cancelEdit() {
        editing = nil
        focusToken += 1
    }

    func saveAsSnippet(_ row: PanelRow?) {
        guard case .clip(let item)? = row, item.kind.isTextual, let text = item.text else { return }
        store.addSnippet(title: item.customTitle ?? ClipItem.firstLine(of: text), body: text)
        HUD.show(String(localized: "Saved to snippets"), symbol: "text.quote")
    }

    func openSettings() {
        PanelController.shared.close()
        SettingsWindowController.shared.show()
    }

    // MARK: Keyboard

    private static let numberKeys: [Int: Int] = [
        kVK_ANSI_1: 0, kVK_ANSI_2: 1, kVK_ANSI_3: 2, kVK_ANSI_4: 3, kVK_ANSI_5: 4,
        kVK_ANSI_6: 5, kVK_ANSI_7: 6, kVK_ANSI_8: 7, kVK_ANSI_9: 8, kVK_ANSI_0: 9,
    ]

    /// Returns true when the key was handled and shouldn't reach the text field.
    func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        let shift = flags.contains(.shift)
        let option = flags.contains(.option)
        let code = Int(event.keyCode)
        let isReturn = code == kVK_Return || code == kVK_ANSI_KeypadEnter

        if editing != nil {
            if code == kVK_Escape { cancelEdit(); return true }
            if isReturn, command { commitEdit(); return true }
            return false
        }

        if isReturn {
            activate(mode: shift ? .plainText : option ? .copyOnly : .paste)
            return true
        }

        switch code {
        case kVK_DownArrow:
            move(by: command ? Int.max / 2 : 1)
            return true
        case kVK_UpArrow:
            move(by: command ? -Int.max / 2 : -1)
            return true
        case kVK_PageDown:
            move(by: 8)
            return true
        case kVK_PageUp:
            move(by: -8)
            return true
        case kVK_Escape:
            if query.isEmpty { PanelController.shared.close() } else { query = "" }
            return true
        case kVK_Tab:
            cycleFilter(forward: !shift)
            return true
        case kVK_Space where query.isEmpty && !command:
            showPreview.toggle()
            return true
        default:
            break
        }

        guard command else { return false }

        if let number = Self.numberKeys[code] {
            activate(at: number, mode: shift ? .plainText : .paste)
            return true
        }

        switch code {
        case kVK_ANSI_P: togglePin(selectedRow)
        case kVK_ANSI_E: beginEdit(selectedRow)
        case kVK_Delete: delete(selectedRow)
        case kVK_ANSI_Y: showPreview.toggle()
        case kVK_ANSI_S: saveAsSnippet(selectedRow)
        case kVK_ANSI_Comma: openSettings()
        case kVK_ANSI_F: focusToken += 1
        case kVK_ANSI_W, kVK_ANSI_Q: PanelController.shared.close()
        default: return false
        }
        return true
    }
}
