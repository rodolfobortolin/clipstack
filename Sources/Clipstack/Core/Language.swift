import AppKit

/// The languages Clipstack ships in. "System" follows macOS (System Settings →
/// General → Language & Region); the others override it for Clipstack only.
nonisolated enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case portuguese = "pt-BR"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case japanese = "ja"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    /// Each language in its own name, as macOS lists them.
    var nativeName: String {
        switch self {
        case .system: String(localized: "System language")
        case .english: "English"
        case .portuguese: "Português (Brasil)"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .italian: "Italiano"
        case .japanese: "日本語"
        case .chinese: "简体中文"
        }
    }
}

extension AppLanguage {
    private static let appleLanguagesKey = "AppleLanguages"

    /// The override stored in Clipstack's own defaults, ignoring the global list.
    static var current: AppLanguage {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let languages = UserDefaults.standard.persistentDomain(forName: bundleID)?[appleLanguagesKey] as? [String],
              let first = languages.first
        else { return .system }
        return AppLanguage(rawValue: first) ?? .system
    }

    /// Takes effect the next time Clipstack starts.
    func apply() {
        if self == .system {
            UserDefaults.standard.removeObject(forKey: Self.appleLanguagesKey)
        } else {
            UserDefaults.standard.set([rawValue], forKey: Self.appleLanguagesKey)
        }
    }

    static func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.7; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }
}
