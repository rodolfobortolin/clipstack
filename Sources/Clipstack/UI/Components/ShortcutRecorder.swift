import AppKit
import SwiftUI

/// Click, then press the new combination. ⎋ cancels, ⌫ clears.
struct ShortcutRecorder: View {
    @Binding var shortcut: Shortcut?
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggleRecording) {
                Text(label)
                    .font(.system(size: 13, weight: isRecording ? .regular : .medium, design: .rounded))
                    .foregroundStyle(isRecording ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .frame(minWidth: 130)
            }
            if shortcut != nil, !isRecording {
                Button {
                    shortcut = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Remove shortcut")
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private var label: String {
        if isRecording { return String(localized: "Type shortcut…") }
        return shortcut?.displayString ?? String(localized: "Record Shortcut")
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        HotKeyCenter.shared.suspendAll()
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case 53: // ⎋
                stopRecording()
            case 51 where event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty: // ⌫
                shortcut = nil
                stopRecording()
            default:
                if let recorded = Shortcut(event: event) {
                    shortcut = recorded
                    stopRecording()
                } else {
                    NSSound.beep()
                }
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        HotKeyCenter.shared.resumeAll()
    }
}
