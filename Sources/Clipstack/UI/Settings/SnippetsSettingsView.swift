import SwiftUI

struct SnippetsSettingsView: View {
    @State private var selection: UUID?

    private var store: ClipStore { .shared }
    private var selected: Snippet? { store.snippets.first { $0.id == selection } }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(store.snippets) { snippet in
                        Text(snippet.displayTitle.isEmpty ? String(localized: "Untitled") : snippet.displayTitle)
                            .lineLimit(1)
                            .tag(snippet.id)
                    }
                }
                .listStyle(.sidebar)
                Divider()
                HStack(spacing: 2) {
                    Button(action: add) {
                        Image(systemName: "plus").frame(width: 22, height: 20)
                    }
                    .help("New snippet")
                    Button(action: remove) {
                        Image(systemName: "minus").frame(width: 22, height: 20)
                    }
                    .disabled(selected == nil)
                    .help("Delete snippet")
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(6)
            }
            .frame(width: 200)

            Divider()

            if let selected {
                SnippetEditor(snippet: selected)
                    .id(selected.id)
            } else {
                ContentUnavailableView(
                    "No Snippet Selected", systemImage: "text.quote",
                    description: Text("Keep the text you use all the time: signatures, canned replies, commands.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 680, height: 480)
        .onAppear { if selection == nil { selection = store.snippets.first?.id } }
        .onDisappear { store.save() }
    }

    private func add() {
        let snippet = store.addSnippet(title: String(localized: "New Snippet"), body: "")
        selection = snippet.id
    }

    private func remove() {
        guard let selected else { return }
        let index = store.snippets.firstIndex { $0.id == selected.id } ?? 0
        store.delete(selected)
        let remaining = store.snippets
        selection = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
    }
}

private struct SnippetEditor: View {
    @Bindable var snippet: Snippet

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: $snippet.title)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .semibold))

            TextEditor(text: $snippet.body)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.separator))

            VStack(alignment: .leading, spacing: 4) {
                Text("Variables")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                ForEach(SnippetExpander.variables, id: \.token) { variable in
                    HStack(spacing: 6) {
                        Text(variable.token)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                        Text(variable.meaning)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if snippet.body.contains("{") {
                GroupBox("Preview") {
                    Text(SnippetExpander.expand(snippet.body, clipboard: NSPasteboard.general.string(forType: .string)))
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(4)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
