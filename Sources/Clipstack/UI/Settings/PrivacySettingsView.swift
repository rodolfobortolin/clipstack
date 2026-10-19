import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PrivacySettingsView: View {
    @Bindable private var settings = AppSettings.shared
    @State private var confirmingClear = false

    private var store: ClipStore { .shared }

    private var recording: Binding<Bool> {
        Binding(
            get: { settings.isRecordingActive },
            set: { $0 ? settings.resume() : settings.pause(minutes: nil) }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle("Record history", isOn: recording)
                Toggle("Ignore passwords and sensitive data", isOn: $settings.ignoreConcealed)
            } footer: {
                Text("Password managers mark what they copy as confidential. With this on, Clipstack never keeps those items.")
            }

            Section {
                ForEach(settings.excludedBundleIDs, id: \.self) { bundleID in
                    HStack(spacing: 10) {
                        if let icon = AppIconCache.shared.icon(for: bundleID) {
                            Image(nsImage: icon).resizable().frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "app.dashed").frame(width: 20, height: 20)
                        }
                        Text(AppIconCache.shared.name(for: bundleID))
                        Spacer()
                        Button {
                            settings.excludedBundleIDs.removeAll { $0 == bundleID }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Record from this app again")
                    }
                }
                HStack {
                    Menu("Add Running App") {
                        ForEach(runningApps, id: \.bundleIdentifier) { app in
                            Button(app.localizedName ?? app.bundleIdentifier ?? "") {
                                add(app.bundleIdentifier)
                            }
                        }
                    }
                    .fixedSize()
                    Button("Choose…", action: chooseApp)
                }
            } header: {
                Text("Ignored apps")
            } footer: {
                Text("Nothing copied in these apps goes into the history.")
            }

            Section("Data") {
                LabeledContent("Stored") {
                    Text("\(store.clips.count) items · \(store.pinnedCount) pinned · \(store.snippets.count) snippets")
                }
                Button("Clear History…", role: .destructive) { confirmingClear = true }
                    .confirmationDialog("Clear the history?", isPresented: $confirmingClear) {
                        Button("Clear", role: .destructive) { store.clearHistory() }
                    } message: {
                        Text("Pinned items and snippets are kept.")
                    }
                Toggle("Sync with iCloud", isOn: $settings.iCloudSync)
                    .disabled(!Entitlements.hasCloudKit)
            }

            Section {
            } footer: {
                if Entitlements.hasCloudKit {
                    Text("Reopen Clipstack to turn sync on or off.")
                } else {
                    Text("Sync needs an App ID with iCloud in the Apple Developer portal. The README has the steps.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 620)
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .filter { !settings.excludedBundleIDs.contains($0.bundleIdentifier ?? "") }
            .filter { $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func add(_ bundleID: String?) {
        guard let bundleID, !settings.excludedBundleIDs.contains(bundleID) else { return }
        settings.excludedBundleIDs.append(bundleID)
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = String(localized: "Ignore")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            add(Bundle(url: url)?.bundleIdentifier)
        }
    }
}
