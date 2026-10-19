import SwiftUI

/// Rename a clip or edit its text without leaving the panel.
struct EditOverlay: View {
    @Bindable var model: PanelModel
    @FocusState private var focus: Field?

    private enum Field { case title, body }

    var body: some View {
        if let draft = Binding($model.editing) {
            ZStack {
                Rectangle()
                    .fill(.black.opacity(0.28))
                    .onTapGesture { model.cancelEdit() }

                VStack(alignment: .leading, spacing: 12) {
                    Group {
                        if draft.wrappedValue.canEditBody { Text("Edit") } else { Text("Rename") }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    TextField("Name (optional)", text: draft.title)
                        .textFieldStyle(.roundedBorder)
                        .focused($focus, equals: .title)
                    if draft.wrappedValue.canEditBody {
                        TextEditor(text: draft.body)
                            .font(.system(size: 13))
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.separator))
                            .focused($focus, equals: .body)
                    }
                    HStack {
                        Text("⌘↩ to save · ⎋ to cancel")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Cancel", action: model.cancelEdit)
                        Button("Save", action: model.commitEdit)
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(18)
                .frame(width: 540, height: draft.wrappedValue.canEditBody ? 360 : 150)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.primary.opacity(0.08)))
                .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
            }
            .onAppear { focus = draft.wrappedValue.canEditBody ? .body : .title }
        }
    }
}
