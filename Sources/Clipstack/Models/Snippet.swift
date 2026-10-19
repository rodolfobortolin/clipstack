import Foundation
import SwiftData

/// A reusable text the user keeps on purpose, with optional variables such as
/// `{date}` or `{clipboard}` that are filled in when it is pasted.
@Model
nonisolated final class Snippet {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var createdAt: Date = Date()
    var sortIndex: Int = 0

    init(title: String, body: String, sortIndex: Int) {
        self.title = title
        self.body = body
        self.sortIndex = sortIndex
    }

    var displayTitle: String {
        title.isEmpty ? ClipItem.firstLine(of: body) : title
    }

    func matches(_ query: String) -> Bool {
        title.localizedStandardContains(query) || body.localizedStandardContains(query)
    }
}
