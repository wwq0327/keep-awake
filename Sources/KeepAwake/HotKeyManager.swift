import AppKit
import Carbon

protocol HotKeyRegistering: AnyObject {
    var onToggle: (@MainActor () -> Void)? { get set }
    func registerDefaultHotKey() -> String?
    func unregister()
}

/// Registers one global hotkey (⌃⌥⌘K) via Carbon `RegisterEventHotKey`.
///
/// Carbon hotkeys fire app-wide without requiring Accessibility permission
/// (unlike `NSEvent.addGlobalMonitorForEvents`), which keeps the first-run
/// experience friction-free.
final class HotKeyManager: HotKeyRegistering {

    /// Invoked on the main thread when the hotkey is pressed.
    var onToggle: (@MainActor () -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x4B574131), id: 1) // 'KWA1'

    /// Return a user-facing error if this shortcut is unavailable.
    func registerDefaultHotKey() -> String? {
        register(
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: UInt32(cmdKey | optionKey | controlKey)
        )
    }

    private func register(keyCode: UInt32, modifiers: UInt32) -> String? {
        unregister()
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var pressedID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressedID
                )
                guard status == noErr else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData)
                    .takeUnretainedValue()
                guard pressedID.signature == manager.hotKeyID.signature,
                      pressedID.id == manager.hotKeyID.id else { return noErr }
                // Extract the @MainActor action first: a global-actor function
                // value is Sendable, so it can safely hop to the main actor.
                let action = manager.onToggle
                MainActor.assumeIsolated {
                    action?()
                }
                return noErr
            },
            1, &eventType, userData, &eventHandlerRef
        )
        if handlerStatus != noErr {
            return localized("快捷键初始化失败（\(handlerStatus)），请使用面板开关。", "Could not initialize the shortcut (\(handlerStatus)). Use the panel switch.")
        }

        let registerStatus = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef
        )
        if registerStatus != noErr {
            unregister()
            return localized("快捷键不可用，可能已被占用（\(registerStatus)），请使用面板开关。", "Shortcut unavailable; it may already be in use (\(registerStatus)). Use the panel switch.")
        }
        return nil
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    deinit { unregister() }
}
