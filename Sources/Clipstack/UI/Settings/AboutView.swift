import SwiftUI

struct AboutView: View {
    private var store: ClipStore { .shared }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return String(localized: "Version \(short) (\(build))")
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Clipstack")
                .font(.system(size: 26, weight: .semibold))
            Text(version)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("Everything you copy, always at hand.")
                .font(.system(size: 13))
                .padding(.top, 4)
            Text("\(store.clips.count) items in history · \(store.snippets.count) snippets")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer().frame(height: 8)
            Text("Made by Rodolfo Bortolin")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(30)
        .frame(width: 560, height: 320)
    }
}
