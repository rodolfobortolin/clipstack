import Foundation
import SwiftData

nonisolated enum ClipKind: String, CaseIterable, Sendable {
    case text, richText, link, image, file, color

    var title: String {
        switch self {
        case .text: String(localized: "Text")
        case .richText: String(localized: "Rich Text")
        case .link: String(localized: "Link")
        case .image: String(localized: "Image")
        case .file: String(localized: "File")
        case .color: String(localized: "Color")
        }
    }

    /// Kinds whose content is a string the user can edit or turn into a snippet.
    var isTextual: Bool {
        switch self {
        case .text, .richText, .link, .color: true
        case .image, .file: false
        }
    }
}

/// One entry of the clipboard history.
///
/// Every stored property has a default and nothing is unique, which is what
/// SwiftData needs to mirror the store to CloudKit when iCloud sync is on.
@Model
nonisolated final class ClipItem {
    var id: UUID = UUID()
    var kindRaw: String = ClipKind.text.rawValue
    /// Plain-text representation: the text itself, a URL, a hex color or the
    /// file paths. Used for display, search and plain-text pastes.
    var text: String?
    @Attribute(.externalStorage) var rtfData: Data?
    @Attribute(.externalStorage) var imageData: Data?
    var thumbnailData: Data?
    var imageWidth: Int = 0
    var imageHeight: Int = 0
    /// Newline-separated, since CloudKit-backed models avoid array attributes.
    var filePaths: String?
    var customTitle: String?
    var isPinned: Bool = false
    var pinnedAt: Date?
    var createdAt: Date = Date()
    var lastUsedAt: Date?
    var useCount: Int = 0
    var sourceBundleID: String?
    var sourceAppName: String?
    var contentHash: String = ""

    init(captured clip: CapturedClip) {
        kindRaw = clip.kind.rawValue
        text = clip.text
        rtfData = clip.rtfData
        imageData = clip.imageData
        thumbnailData = clip.thumbnailData
        imageWidth = Int(clip.imageSize.width)
        imageHeight = Int(clip.imageSize.height)
        filePaths = clip.filePaths.isEmpty ? nil : clip.filePaths.joined(separator: "\n")
        sourceBundleID = clip.sourceBundleID
        sourceAppName = clip.sourceAppName
        contentHash = clip.contentHash
    }

    var kind: ClipKind {
        get { ClipKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }

    var filePathList: [String] {
        (filePaths ?? "").split(separator: "\n").map(String.init)
    }

    var fileURLs: [URL] {
        filePathList.map { URL(fileURLWithPath: $0) }
    }

    var displayTitle: String {
        if let customTitle, !customTitle.isEmpty { return customTitle }
        switch kind {
        case .image:
            return imageWidth > 0 ? String(localized: "Image \(imageWidth)×\(imageHeight)") : String(localized: "Image")
        case .file:
            let names = filePathList.map { ($0 as NSString).lastPathComponent }
            guard let first = names.first else { return String(localized: "File") }
            return names.count > 1 ? String(localized: "\(first) and \(names.count - 1) more") : first
        case .color:
            return (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        case .link:
            let link = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return link.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
        case .text, .richText:
            return Self.firstLine(of: text ?? "")
        }
    }

    func matches(_ query: String) -> Bool {
        if let customTitle, customTitle.localizedStandardContains(query) { return true }
        if let sourceAppName, sourceAppName.localizedStandardContains(query) { return true }
        // Very long clips are searched by their beginning only, so typing stays instant.
        if let text, text.prefix(20_000).localizedStandardContains(query) { return true }
        return false
    }

    static func firstLine(of text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        let collapsed = line.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(collapsed.prefix(240))
    }
}

/// What the clipboard monitor read, before it becomes a stored `ClipItem`.
nonisolated struct CapturedClip: Sendable {
    var kind: ClipKind
    var text: String?
    var rtfData: Data?
    var imageData: Data?
    var thumbnailData: Data?
    var imageSize: CGSize = .zero
    var filePaths: [String] = []
    var sourceBundleID: String?
    var sourceAppName: String?
    var contentHash: String
}
