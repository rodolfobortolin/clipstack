import AppKit
import Carbon.HIToolbox

/// Registers system-wide shortcuts. Carbon's `RegisterEventHotKey` is still
/// the only public API for this, and needs no permission.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    enum Action: UInt32 {
        case panel = 1
        case cursorMenu = 2
    }

    private let signature: OSType = 0x434C_5354 // 'CLST'
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var shortcuts: [UInt32: Shortcut] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    private var isSuspended = false

    func register(_ action: Action, shortcut: Shortcut?, handler: @escaping () -> Void) {
        unregisterRef(action.rawValue)
        handlers[action.rawValue] = handler
        shortcuts[action.rawValue] = shortcut
        if !isSuspended { registerRef(action.rawValue) }
    }

    /// Releases every shortcut while the user records a new one, so pressing
    /// the current combination reaches the recorder instead of firing.
    func suspendAll() {
        guard !isSuspended else { return }
        isSuspended = true
        refs.keys.forEach(unregisterRef)
    }

    func resumeAll() {
        guard isSuspended else { return }
        isSuspended = false
        shortcuts.keys.forEach(registerRef)
    }

    fileprivate func handle(id: UInt32) {
        handlers[id]?()
    }

    private func registerRef(_ id: UInt32) {
        guard let shortcut = shortcuts[id] else { return }
        installHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref
        )
        if status == noErr, let ref {
            refs[id] = ref
        } else {
            NSLog("Clipstack: could not register shortcut \(shortcut.displayString) (\(status))")
        }
    }

    private func unregisterRef(_ id: UInt32) {
        if let ref = refs.removeValue(forKey: id) {
            UnregisterEventHotKey(ref)
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler, 1, &spec, nil, &eventHandler)
    }
}

/// Carbon delivers hot key events on the main thread.
private nonisolated func hotKeyEventHandler(
    _ next: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
    )
    guard status == noErr else { return status }
    let id = hotKeyID.id
    MainActor.assumeIsolated {
        HotKeyCenter.shared.handle(id: id)
    }
    return noErr
}
