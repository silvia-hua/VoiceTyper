import Carbon
import Foundation

final class HotkeyManager {
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var isKeyDown = false

    deinit {
        unregister()
    }

    func register(hotkey: Hotkey) throws {
        unregister()
        installEventHandlerIfNeeded()

        let hotkeyID = EventHotKeyID(signature: fourCharacterCode("VTyp"), id: 1)
        var newHotkeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &newHotkeyRef
        )

        guard status == noErr, let newHotkeyRef else {
            throw HotkeyError.registrationFailed(status)
        }
        hotkeyRef = newHotkeyRef
    }

    private func unregister() {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        isKeyDown = false
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handle(event: event)
                return noErr
            },
            eventTypes.count,
            &eventTypes,
            selfPointer,
            &eventHandlerRef
        )
    }

    private func handle(event: EventRef) {
        switch GetEventKind(event) {
        case UInt32(kEventHotKeyPressed):
            guard !isKeyDown else { return }
            isKeyDown = true
            onPressed?()
        case UInt32(kEventHotKeyReleased):
            guard isKeyDown else { return }
            isKeyDown = false
            onReleased?()
        default:
            break
        }
    }
}

private func fourCharacterCode(_ string: String) -> OSType {
    var result: OSType = 0
    for scalar in string.unicodeScalars.prefix(4) {
        result = (result << 8) + OSType(scalar.value)
    }
    return result
}

enum HotkeyError: LocalizedError {
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let status):
            "系统返回 \(status)"
        }
    }
}
