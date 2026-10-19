import AppKit
import Observation

extension Notification.Name {
    static let clipstackShortcutsChanged = Notification.Name("ClipstackShortcutsChanged")
    static let clipstackPauseChanged = Notification.Name("ClipstackPauseChanged")
}

/// User preferences, persisted in `UserDefaults` and observable by SwiftUI.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    @ObservationIgnored private let defaults = UserDefaults.standard

    var historyLimit: Int { didSet { defaults.set(historyLimit, forKey: Key.historyLimit) } }
    var captureImages: Bool { didSet { defaults.set(captureImages, forKey: Key.captureImages) } }
    var captureFiles: Bool { didSet { defaults.set(captureFiles, forKey: Key.captureFiles) } }
    var pasteAutomatically: Bool { didSet { defaults.set(pasteAutomatically, forKey: Key.pasteAutomatically) } }
    var plainTextByDefault: Bool { didSet { defaults.set(plainTextByDefault, forKey: Key.plainTextByDefault) } }
    var movePastedToTop: Bool { didSet { defaults.set(movePastedToTop, forKey: Key.movePastedToTop) } }
    var singleClickPastes: Bool { didSet { defaults.set(singleClickPastes, forKey: Key.singleClickPastes) } }
    var showPreview: Bool { didSet { defaults.set(showPreview, forKey: Key.showPreview) } }
    var ignoreConcealed: Bool { didSet { defaults.set(ignoreConcealed, forKey: Key.ignoreConcealed) } }
    var excludedBundleIDs: [String] { didSet { defaults.set(excludedBundleIDs, forKey: Key.excludedBundleIDs) } }
    var iCloudSync: Bool { didSet { defaults.set(iCloudSync, forKey: Key.iCloudSync) } }
    var hasLaunchedBefore: Bool { didSet { defaults.set(hasLaunchedBefore, forKey: Key.hasLaunchedBefore) } }

    var panelPosition: PanelPosition { didSet { defaults.set(panelPosition.rawValue, forKey: Key.panelPosition) } }
    var panelMaterial: PanelMaterial { didSet { defaults.set(panelMaterial.rawValue, forKey: Key.panelMaterial) } }
    var density: RowDensity { didSet { defaults.set(density.rawValue, forKey: Key.density) } }
    var accent: AccentChoice { didSet { defaults.set(accent.rawValue, forKey: Key.accent) } }
    var appearance: AppearanceMode {
        didSet {
            defaults.set(appearance.rawValue, forKey: Key.appearance)
            applyAppearance()
        }
    }

    var panelShortcut: Shortcut? {
        didSet {
            store(panelShortcut, forKey: Key.panelShortcut)
            NotificationCenter.default.post(name: .clipstackShortcutsChanged, object: nil)
        }
    }
    var menuShortcut: Shortcut? {
        didSet {
            store(menuShortcut, forKey: Key.menuShortcut)
            NotificationCenter.default.post(name: .clipstackShortcutsChanged, object: nil)
        }
    }

    var isPaused: Bool {
        didSet {
            defaults.set(isPaused, forKey: Key.isPaused)
            NotificationCenter.default.post(name: .clipstackPauseChanged, object: nil)
        }
    }
    var pausedUntil: Date? {
        didSet {
            defaults.set(pausedUntil, forKey: Key.pausedUntil)
            NotificationCenter.default.post(name: .clipstackPauseChanged, object: nil)
        }
    }

    /// Whether new copies are being recorded right now.
    var isRecordingActive: Bool {
        if isPaused { return false }
        if let pausedUntil, pausedUntil > Date() { return false }
        return true
    }

    static let historyLimitChoices = [50, 100, 200, 500, 1000, 2000, 5000, 10_000]

    /// Password managers and the Keychain, which also mark what they copy as
    /// concealed. Listing them covers the ones that don't.
    static let defaultExcludedApps = [
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
    ]

    private init() {
        defaults.register(defaults: [
            Key.historyLimit: 500,
            Key.captureImages: true,
            Key.captureFiles: true,
            Key.pasteAutomatically: true,
            Key.plainTextByDefault: false,
            Key.movePastedToTop: true,
            Key.singleClickPastes: false,
            Key.showPreview: true,
            Key.ignoreConcealed: true,
            Key.excludedBundleIDs: Self.defaultExcludedApps,
            Key.iCloudSync: false,
            Key.hasLaunchedBefore: false,
            Key.isPaused: false,
        ])

        historyLimit = defaults.integer(forKey: Key.historyLimit)
        captureImages = defaults.bool(forKey: Key.captureImages)
        captureFiles = defaults.bool(forKey: Key.captureFiles)
        pasteAutomatically = defaults.bool(forKey: Key.pasteAutomatically)
        plainTextByDefault = defaults.bool(forKey: Key.plainTextByDefault)
        movePastedToTop = defaults.bool(forKey: Key.movePastedToTop)
        singleClickPastes = defaults.bool(forKey: Key.singleClickPastes)
        showPreview = defaults.bool(forKey: Key.showPreview)
        ignoreConcealed = defaults.bool(forKey: Key.ignoreConcealed)
        excludedBundleIDs = defaults.stringArray(forKey: Key.excludedBundleIDs) ?? Self.defaultExcludedApps
        iCloudSync = defaults.bool(forKey: Key.iCloudSync)
        hasLaunchedBefore = defaults.bool(forKey: Key.hasLaunchedBefore)
        isPaused = defaults.bool(forKey: Key.isPaused)
        pausedUntil = defaults.object(forKey: Key.pausedUntil) as? Date

        panelPosition = PanelPosition(rawValue: defaults.string(forKey: Key.panelPosition) ?? "") ?? .center
        panelMaterial = PanelMaterial(rawValue: defaults.string(forKey: Key.panelMaterial) ?? "") ?? .glass
        density = RowDensity(rawValue: defaults.string(forKey: Key.density) ?? "") ?? .comfortable
        accent = AccentChoice(rawValue: defaults.string(forKey: Key.accent) ?? "") ?? .multicolor
        appearance = AppearanceMode(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system

        panelShortcut = Self.readShortcut(defaults, Key.panelShortcut, fallback: .defaultPanel)
        menuShortcut = Self.readShortcut(defaults, Key.menuShortcut, fallback: .defaultMenu)

        scheduleResumeIfNeeded()
    }

    func applyAppearance() {
        NSApp.appearance = appearance.nsAppearance
    }

    /// Pauses recording until resumed, or for a number of minutes.
    func pause(minutes: Int?) {
        if let minutes {
            isPaused = false
            pausedUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
            scheduleResumeIfNeeded()
        } else {
            pausedUntil = nil
            isPaused = true
        }
    }

    func resume() {
        isPaused = false
        pausedUntil = nil
    }

    private func scheduleResumeIfNeeded() {
        guard let until = pausedUntil else { return }
        let delay = until.timeIntervalSinceNow
        guard delay > 0 else {
            pausedUntil = nil
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(delay))
            if let current = self.pausedUntil, current <= Date() { self.pausedUntil = nil }
        }
    }

    private func store(_ shortcut: Shortcut?, forKey key: String) {
        // An empty value means "no shortcut", as opposed to a missing key, which means the default.
        let data = shortcut.flatMap { try? JSONEncoder().encode($0) } ?? Data()
        defaults.set(data, forKey: key)
    }

    private static func readShortcut(_ defaults: UserDefaults, _ key: String, fallback: Shortcut) -> Shortcut? {
        guard let data = defaults.data(forKey: key) else { return fallback }
        guard !data.isEmpty else { return nil }
        return (try? JSONDecoder().decode(Shortcut.self, from: data)) ?? fallback
    }

    private enum Key {
        static let historyLimit = "historyLimit"
        static let captureImages = "captureImages"
        static let captureFiles = "captureFiles"
        static let pasteAutomatically = "pasteAutomatically"
        static let plainTextByDefault = "plainTextByDefault"
        static let movePastedToTop = "movePastedToTop"
        static let singleClickPastes = "singleClickPastes"
        static let showPreview = "showPreview"
        static let ignoreConcealed = "ignoreConcealed"
        static let excludedBundleIDs = "excludedBundleIDs"
        static let iCloudSync = "iCloudSync"
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let isPaused = "isPaused"
        static let pausedUntil = "pausedUntil"
        static let panelPosition = "panelPosition"
        static let panelMaterial = "panelMaterial"
        static let density = "density"
        static let accent = "accent"
        static let appearance = "appearance"
        static let panelShortcut = "panelShortcut"
        static let menuShortcut = "menuShortcut"
    }
}
