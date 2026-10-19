import SwiftUI

struct ShortcutsSettingsView: View {
    @Bindable private var settings = AppSettings.shared

    private let panelKeys: [(keys: String, action: LocalizedStringKey)] = [
        ("↩", "Paste"),
        ("⇧↩", "Paste as plain text"),
        ("⌥↩", "Copy only"),
        ("⌘1 … ⌘0", "Paste one of the first ten"),
        ("↑ ↓", "Move through the list"),
        ("⇥", "Switch filter"),
        (String(localized: "Space") + "  ·  ⌘Y", "Show or hide the preview"),
        ("⌘P", "Pin or unpin"),
        ("⌘E", "Edit or rename"),
        ("⌘S", "Save as snippet"),
        ("⌘⌫", "Delete"),
        ("⎋", "Clear the search or close"),
    ]

    var body: some View {
        Form {
            Section {
                LabeledContent("Open history") {
                    ShortcutRecorder(shortcut: $settings.panelShortcut)
                }
                LabeledContent("Menu at pointer") {
                    ShortcutRecorder(shortcut: $settings.menuShortcut)
                }
            } footer: {
                Text("The pointer menu opens wherever the mouse is, with pinned items, recent items and snippets. The numbers 1 to 0 paste right away.")
            }

            Section("In the panel") {
                ForEach(panelKeys, id: \.keys) { keys, action in
                    LabeledContent(action) {
                        Text(keys)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 620)
    }
}
