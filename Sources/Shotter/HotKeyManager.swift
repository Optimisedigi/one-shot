import AppKit
import Carbon

enum KeyCodes {
    static let one: UInt32 = 18
    static let two: UInt32 = 19
    static let three: UInt32 = 20
    static let four: UInt32 = 21
    static let five: UInt32 = 23
}

struct HotKeyModifiers: OptionSet {
    let rawValue: UInt32

    static let command = HotKeyModifiers(rawValue: UInt32(cmdKey))
    static let shift = HotKeyModifiers(rawValue: UInt32(shiftKey))
    static let option = HotKeyModifiers(rawValue: UInt32(optionKey))
    static let control = HotKeyModifiers(rawValue: UInt32(controlKey))
}

enum HotKeyError: LocalizedError {
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let status):
            return "RegisterEventHotKey failed with status \(status)."
        }
    }
}

final class HotKeyManager {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var eventHandlerInstalled = false
    private static var nextID: UInt32 = 1

    private let keyCode: UInt32
    private let modifiers: HotKeyModifiers
    private let handler: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private let id: UInt32

    init(keyCode: UInt32, modifiers: HotKeyModifiers, handler: @escaping () -> Void) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.handler = handler
        self.id = Self.nextID
        Self.nextID += 1
    }

    deinit {
        unregister()
    }

    func register() throws {
        try Self.installEventHandlerIfNeeded()
        let eventID = EventHotKeyID(signature: fourCharCode("SHOT"), id: id)
        let status = RegisterEventHotKey(keyCode, modifiers.rawValue, eventID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else { throw HotKeyError.registrationFailed(status) }
        Self.handlers[id] = handler
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        Self.handlers.removeValue(forKey: id)
    }

    private static func installEventHandlerIfNeeded() throws {
        guard !eventHandlerInstalled else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            DispatchQueue.main.async {
                HotKeyManager.handlers[hotKeyID.id]?()
            }
            return noErr
        }, 1, &eventType, nil, nil)
        guard status == noErr else { throw HotKeyError.registrationFailed(status) }
        eventHandlerInstalled = true
    }
}

private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for scalar in string.unicodeScalars.prefix(4) {
        result = (result << 8) + OSType(scalar.value)
    }
    return result
}
