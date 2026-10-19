import AppKit
import Carbon.HIToolbox

nonisolated enum PasteMode: Sendable {
    case paste, plainText, copyOnly
}

/// Puts an item back on the pasteboard and, when allowed, pastes it into the
/// app in front by sending ⌘V.
final class Paster {
    static let shared = Paster()

    static let sourceType = NSPasteboard.PasteboardType("org.nspasteboard.source")

    private let pasteboard = NSPasteboard.general
    private let settings = AppSettings.shared

    func perform(_ item: ClipItem, mode: PasteMode, target: NSRunningApplication? = nil) {
        let plain = mode == .plainText || settings.plainTextByDefault
        write(item, plain: plain)
        ClipStore.shared.markUsed(item)
        finish(mode: mode, target: target)
    }

    func perform(snippet: Snippet, mode: PasteMode, target: NSRunningApplication? = nil) {
        let text = SnippetExpander.expand(snippet.body, clipboard: pasteboard.string(forType: .string))
        writeString(text)
        finish(mode: mode, target: target)
    }

    private func finish(mode: PasteMode, target: NSRunningApplication?) {
        ClipboardMonitor.shared.skipCurrentChange()

        guard mode != .copyOnly, settings.pasteAutomatically else {
            HUD.show(String(localized: "Copied"), symbol: "doc.on.doc")
            return
        }
        guard Permissions.isAccessibilityTrusted else {
            Permissions.requestAccessibility()
            HUD.show(String(localized: "Copied. Allow Accessibility to paste directly."), symbol: "hand.raised")
            return
        }

        var delay = 60
        if let target, !target.isActive {
            target.activate()
            delay = 180
        }
        Task {
            try? await Task.sleep(for: .milliseconds(delay))
            Self.postCommandV()
        }
    }

    private func write(_ item: ClipItem, plain: Bool) {
        pasteboard.clearContents()
        switch item.kind {
        case .image:
            if let data = item.imageData {
                pasteboard.declareTypes([.png, .tiff], owner: nil)
                pasteboard.setData(data, forType: .png)
                if let tiff = NSImage(data: data)?.tiffRepresentation {
                    pasteboard.setData(tiff, forType: .tiff)
                }
            }
        case .file:
            pasteboard.writeObjects(item.fileURLs as [NSURL])
        case .text, .richText, .link, .color:
            let text = item.text ?? ""
            if !plain, item.kind == .richText, let rtf = item.rtfData {
                pasteboard.declareTypes([.rtf, .string], owner: nil)
                pasteboard.setData(rtf, forType: .rtf)
            } else {
                pasteboard.declareTypes([.string], owner: nil)
            }
            pasteboard.setString(text, forType: .string)
            if !plain, item.kind == .link {
                pasteboard.addTypes([.URL], owner: nil)
                pasteboard.setString(text.trimmingCharacters(in: .whitespacesAndNewlines), forType: .URL)
            }
        }
        markSource()
    }

    private func writeString(_ text: String) {
        pasteboard.clearContents()
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(text, forType: .string)
        markSource()
    }

    private func markSource() {
        pasteboard.addTypes([Self.sourceType], owner: nil)
        pasteboard.setString(Bundle.main.bundleIdentifier ?? "Clipstack", forType: Self.sourceType)
    }

    /// Sends ⌘V with the command flag set explicitly, so modifiers the user is
    /// still holding (⇧ from ⇧↩, say) don't turn it into another shortcut.
    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let key = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }
}
