import AppKit
import CoreData
import SwiftData

/// Owns the SwiftData container and keeps the history and snippets in memory,
/// newest first, for the panel and the menus.
@Observable
final class ClipStore {
    static let shared = ClipStore()

    @ObservationIgnored let container: ModelContainer
    @ObservationIgnored private let settings = AppSettings.shared

    private(set) var clips: [ClipItem] = []
    private(set) var snippets: [Snippet] = []

    var context: ModelContext { container.mainContext }
    var pinnedCount: Int { clips.lazy.filter(\.isPinned).count }

    private init() {
        container = Self.makeContainer(cloud: AppSettings.shared.iCloudSync && Entitlements.hasCloudKit)
        reload()

        // CloudKit imports changes from other Macs in the background.
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    // MARK: Clips

    func insert(_ clip: CapturedClip) {
        if let existing = clips.first(where: { $0.contentHash == clip.contentHash }) {
            // Copying the same thing again moves it to the top instead of duplicating it.
            existing.createdAt = Date()
            existing.sourceBundleID = clip.sourceBundleID ?? existing.sourceBundleID
            existing.sourceAppName = clip.sourceAppName ?? existing.sourceAppName
            if existing.rtfData == nil, let rtf = clip.rtfData {
                existing.rtfData = rtf
                existing.kind = clip.kind
            }
        } else {
            context.insert(ClipItem(captured: clip))
        }
        save()
        enforceLimit()
    }

    func markUsed(_ item: ClipItem) {
        item.useCount += 1
        item.lastUsedAt = Date()
        if settings.movePastedToTop, !item.isPinned { item.createdAt = Date() }
        save()
    }

    func togglePin(_ item: ClipItem) {
        item.isPinned.toggle()
        item.pinnedAt = item.isPinned ? Date() : nil
        if !item.isPinned { item.createdAt = Date() }
        save()
    }

    func delete(_ item: ClipItem) {
        context.delete(item)
        save()
    }

    func update(_ item: ClipItem, title: String, text: String?) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.customTitle = trimmedTitle.isEmpty ? nil : trimmedTitle
        if let text, item.kind.isTextual, text != item.text {
            item.text = text
            item.rtfData = nil
            item.kind = ClipExtractor.textKind(for: text)
            item.contentHash = ClipExtractor.hash("text", text)
        }
        save()
    }

    /// Deletes everything that isn't pinned. Snippets are kept.
    func clearHistory() {
        try? context.delete(model: ClipItem.self, where: #Predicate { $0.isPinned == false })
        save()
    }

    /// Drops the oldest unpinned clips beyond the history limit.
    ///
    /// The cut happens in memory: SwiftData ignores `fetchOffset` for objects
    /// that aren't saved yet, which would delete the clip just inserted.
    func enforceLimit() {
        let descriptor = FetchDescriptor<ClipItem>(
            predicate: #Predicate { $0.isPinned == false },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let unpinned = try? context.fetch(descriptor), unpinned.count > settings.historyLimit else { return }
        unpinned.dropFirst(settings.historyLimit).forEach(context.delete)
        save()
    }

    // MARK: Snippets

    @discardableResult
    func addSnippet(title: String, body: String) -> Snippet {
        let next = (snippets.map(\.sortIndex).max() ?? 0) + 1
        let snippet = Snippet(title: title, body: body, sortIndex: next)
        context.insert(snippet)
        save()
        return snippet
    }

    func update(_ snippet: Snippet, title: String, body: String) {
        snippet.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        snippet.body = body
        save()
    }

    func delete(_ snippet: Snippet) {
        context.delete(snippet)
        save()
    }

    // MARK: Persistence

    func save() {
        do {
            try context.save()
        } catch {
            NSLog("Clipstack: save failed: \(error)")
        }
        reload()
    }

    func reload() {
        let clipFetch = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        clips = ((try? context.fetch(clipFetch)) ?? []).filter { !$0.isDeleted }

        let snippetFetch = FetchDescriptor<Snippet>(sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)])
        snippets = ((try? context.fetch(snippetFetch)) ?? []).filter { !$0.isDeleted }
    }

    private static func makeContainer(cloud: Bool) -> ModelContainer {
        let schema = Schema([ClipItem.self, Snippet.self])
        let url = AppPaths.storeURL
        let configuration = ModelConfiguration(
            "Clipstack", schema: schema, url: url,
            cloudKitDatabase: cloud ? .private(Entitlements.containerID) : .none
        )
        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }

        // A store that can't be opened is set aside rather than deleted, then we start fresh.
        let stamp = Int(Date().timeIntervalSince1970)
        for suffix in ["", "-wal", "-shm"] {
            let file = URL(fileURLWithPath: url.path + suffix)
            let backup = URL(fileURLWithPath: url.path + ".broken-\(stamp)" + suffix)
            try? FileManager.default.moveItem(at: file, to: backup)
        }
        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }

        let memory = ModelConfiguration("Clipstack", schema: schema, isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: schema, configurations: [memory])
    }
}
