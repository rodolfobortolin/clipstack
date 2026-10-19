import Foundation

/// Fills in a snippet's variables at paste time.
enum SnippetExpander {
    static let variables: [(token: String, meaning: String)] = [
        ("{date}", String(localized: "today's date")),
        ("{time}", String(localized: "the current time")),
        ("{datetime}", String(localized: "date and time")),
        ("{weekday}", String(localized: "day of the week")),
        ("{clipboard}", String(localized: "what is on the clipboard now")),
        ("{uuid}", String(localized: "a new unique ID")),
        ("{date:dd/MM/yyyy}", String(localized: "the date in any format you like")),
    ]

    private static var locale: Locale { AppLocale.current }
    private static let customDate = try? NSRegularExpression(pattern: #"\{date:([^}]+)\}"#)

    static func expand(_ body: String, clipboard: String?, now: Date = Date()) -> String {
        var result = body

        if let customDate {
            let range = NSRange(result.startIndex..., in: result)
            for match in customDate.matches(in: result, range: range).reversed() {
                guard let whole = Range(match.range, in: result),
                      let formatRange = Range(match.range(at: 1), in: result) else { continue }
                let formatter = DateFormatter()
                formatter.locale = locale
                formatter.dateFormat = String(result[formatRange])
                result.replaceSubrange(whole, with: formatter.string(from: now))
            }
        }

        let replacements: [(String, () -> String)] = [
            ("{datetime}", { format(now, date: .short, time: .short) }),
            ("{date}", { format(now, date: .short, time: .none) }),
            ("{time}", { format(now, date: .none, time: .short) }),
            ("{weekday}", { weekday(now) }),
            ("{clipboard}", { clipboard ?? "" }),
            ("{uuid}", { UUID().uuidString }),
        ]
        for (token, value) in replacements where result.contains(token) {
            result = result.replacingOccurrences(of: token, with: value())
        }
        return result
    }

    private static func format(_ date: Date, date dateStyle: DateFormatter.Style, time timeStyle: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }

    private static func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}
