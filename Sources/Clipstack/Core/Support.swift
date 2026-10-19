import AppKit
import ApplicationServices
import Security
import ServiceManagement
import UniformTypeIdentifiers

enum AppPaths {
    /// An explicit location: unsandboxed apps would otherwise share SwiftData's
    /// default `default.store` in Application Support.
    static var storeURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Clipstack", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("Clipstack.store")
    }
}

enum Permissions {
    /// Sending ⌘V to another app needs Accessibility access.
    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibility() {
        // The literal value of kAXTrustedCheckOptionPrompt, which Swift 6 imports as a mutable global.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Clipstack: launch at login change failed: \(error)")
        }
    }
}

enum Entitlements {
    static let containerID = "iCloud.com.rodolfobortolin.Clipstack"

    /// CloudKit sync can only be turned on when the app was signed with an
    /// iCloud entitlement and a matching provisioning profile.
    static let hasCloudKit: Bool = {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        return SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-services" as CFString, nil) != nil
    }()
}

/// Icons and names of the apps clips came from.
final class AppIconCache {
    static let shared = AppIconCache()

    private var icons: [String: NSImage] = [:]
    private var names: [String: String] = [:]
    private var fileIcons: [String: NSImage] = [:]

    func icon(for bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let cached = icons[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[bundleID] = icon
        return icon
    }

    func name(for bundleID: String) -> String {
        if let cached = names[bundleID] { return cached }
        var name = bundleID
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            name = FileManager.default.displayName(atPath: url.path)
            if name.hasSuffix(".app") { name.removeLast(4) }
        }
        names[bundleID] = name
        return name
    }

    func fileIcon(for path: String?) -> NSImage {
        guard let path else { return NSWorkspace.shared.icon(for: .data) }
        if let cached = fileIcons[path] { return cached }
        let icon = FileManager.default.fileExists(atPath: path)
            ? NSWorkspace.shared.icon(forFile: path)
            : NSWorkspace.shared.icon(for: UTType(filenameExtension: (path as NSString).pathExtension) ?? .data)
        fileIcons[path] = icon
        return icon
    }
}

/// Decoded images, so scrolling the list doesn't decode PNGs over and over.
final class ImageCache {
    static let shared = ImageCache()

    private let thumbnails = NSCache<NSString, NSImage>()
    private let images = NSCache<NSString, NSImage>()

    private init() {
        thumbnails.countLimit = 400
        images.countLimit = 12
    }

    func thumbnail(for item: ClipItem) -> NSImage? {
        load(from: thumbnails, key: item.id.uuidString) { item.thumbnailData ?? item.imageData }
    }

    func image(for item: ClipItem) -> NSImage? {
        load(from: images, key: item.id.uuidString) { item.imageData }
    }

    private func load(from cache: NSCache<NSString, NSImage>, key: String, data: () -> Data?) -> NSImage? {
        if let cached = cache.object(forKey: key as NSString) { return cached }
        guard let data = data(), let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: key as NSString)
        return image
    }
}

nonisolated enum ImageTools {
    static func thumbnail(from rep: NSBitmapImageRep, maxPixel: CGFloat) -> Data? {
        guard let cgImage = rep.cgImage else { return nil }
        let width = CGFloat(cgImage.width), height = CGFloat(cgImage.height)
        let scale = min(1, maxPixel / max(width, height))
        let targetWidth = max(1, Int(width * scale)), targetHeight = max(1, Int(height * scale))
        guard let context = CGContext(
            data: nil, width: targetWidth, height: targetHeight, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        guard let scaled = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: scaled).representation(using: .png, properties: [:])
    }
}

/// The locale of the language the app is running in, which can differ from
/// the system region when the user picks a language for Clipstack.
enum AppLocale {
    static let current = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
}

enum Formatters {
    private static let locale = AppLocale.current

    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .short
        return formatter
    }()

    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeStyle = .short
        return formatter
    }()

    static func relativeString(_ date: Date) -> String {
        if Date().timeIntervalSince(date) < 60 { return String(localized: "now") }
        return relative.localizedString(for: date, relativeTo: Date())
    }
}
