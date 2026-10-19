import SwiftUI

struct AppearanceSettingsView: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                LabeledContent("Accent color") {
                    HStack(spacing: 9) {
                        ForEach(AccentChoice.allCases) { choice in
                            AccentDot(choice: choice, isSelected: settings.accent == choice)
                                .onTapGesture { settings.accent = choice }
                                .help(choice.title)
                        }
                    }
                }
            }

            Section("Panel") {
                Picker("Material", selection: $settings.panelMaterial) {
                    ForEach(PanelMaterial.allCases) { Text($0.title).tag($0) }
                }
                Picker("Density", selection: $settings.density) {
                    ForEach(RowDensity.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section {
            } footer: {
                Text("Glass uses Liquid Glass on macOS 26. Earlier versions get a translucent background instead.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 380)
    }
}

private struct AccentDot: View {
    let choice: AccentChoice
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: 18, height: 18)
            .overlay(Circle().strokeBorder(.black.opacity(0.12)))
            .overlay {
                if isSelected {
                    Circle().fill(.white).frame(width: 6, height: 6)
                }
            }
            .contentShape(Circle())
    }

    private var fill: AnyShapeStyle {
        if choice == .multicolor {
            return AnyShapeStyle(AngularGradient(
                colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red], center: .center
            ))
        }
        return AnyShapeStyle(choice.color)
    }
}
