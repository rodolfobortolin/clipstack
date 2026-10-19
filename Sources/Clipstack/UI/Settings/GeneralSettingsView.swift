import Combine
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable private var settings = AppSettings.shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var accessibilityGranted = Permissions.isAccessibilityTrusted
    @State private var language = AppLanguage.current
    private let launchLanguage = AppLanguage.current

    private let permissionCheck = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) {
                        LaunchAtLogin.set(launchAtLogin)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                Picker("Language", selection: $language) {
                    ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0) }
                }
                .onChange(of: language) { language.apply() }
                if language != launchLanguage {
                    LabeledContent("Restart Clipstack to change the language.") {
                        Button("Restart Now", action: AppLanguage.relaunch)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Section("History") {
                Picker("Keep up to", selection: $settings.historyLimit) {
                    ForEach(AppSettings.historyLimitChoices, id: \.self) { limit in
                        Text("\(limit.formatted()) items").tag(limit)
                    }
                }
                .onChange(of: settings.historyLimit) { ClipStore.shared.enforceLimit() }
                Toggle("Save images", isOn: $settings.captureImages)
                Toggle("Save files copied in Finder", isOn: $settings.captureFiles)
            }

            Section {
                Toggle("Paste directly into the current app", isOn: $settings.pasteAutomatically)
                if settings.pasteAutomatically {
                    LabeledContent("Accessibility") {
                        if accessibilityGranted {
                            Label("Allowed", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("Allow…") {
                                Permissions.requestAccessibility()
                                Permissions.openAccessibilitySettings()
                            }
                        }
                    }
                }
                Toggle("Always paste as plain text", isOn: $settings.plainTextByDefault)
                Toggle("Move pasted items to the top", isOn: $settings.movePastedToTop)
                Toggle("Paste with a single click", isOn: $settings.singleClickPastes)
            } header: {
                Text("Paste")
            } footer: {
                Text("To paste for you, Clipstack sends ⌘V to the current app, which macOS only allows with Accessibility turned on.")
            }

            Section("Panel") {
                Picker("Open", selection: $settings.panelPosition) {
                    ForEach(PanelPosition.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Show the preview alongside", isOn: $settings.showPreview)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 640)
        .onReceive(permissionCheck) { _ in
            accessibilityGranted = Permissions.isAccessibilityTrusted
        }
    }
}
