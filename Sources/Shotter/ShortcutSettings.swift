import AppKit

struct ShortcutChoice: Equatable {
    let id: String
    let title: String
    let keyEquivalent: String
    let keyCode: UInt32
    let modifiers: HotKeyModifiers

    static let all: [ShortcutChoice] = [
        ShortcutChoice(id: "cmd-shift-1", title: "⌘⇧1", keyEquivalent: "1", keyCode: KeyCodes.one, modifiers: [.command, .shift]),
        ShortcutChoice(id: "cmd-shift-2", title: "⌘⇧2", keyEquivalent: "2", keyCode: KeyCodes.two, modifiers: [.command, .shift]),
        ShortcutChoice(id: "cmd-shift-3", title: "⌘⇧3", keyEquivalent: "3", keyCode: KeyCodes.three, modifiers: [.command, .shift]),
        ShortcutChoice(id: "cmd-shift-4", title: "⌘⇧4", keyEquivalent: "4", keyCode: KeyCodes.four, modifiers: [.command, .shift]),
        ShortcutChoice(id: "cmd-shift-5", title: "⌘⇧5", keyEquivalent: "5", keyCode: KeyCodes.five, modifiers: [.command, .shift]),
        ShortcutChoice(id: "cmd-option-2", title: "⌘⌥2", keyEquivalent: "2", keyCode: KeyCodes.two, modifiers: [.command, .option]),
        ShortcutChoice(id: "cmd-option-4", title: "⌘⌥4", keyEquivalent: "4", keyCode: KeyCodes.four, modifiers: [.command, .option]),
        ShortcutChoice(id: "ctrl-shift-2", title: "⌃⇧2", keyEquivalent: "2", keyCode: KeyCodes.two, modifiers: [.control, .shift]),
        ShortcutChoice(id: "ctrl-shift-4", title: "⌃⇧4", keyEquivalent: "4", keyCode: KeyCodes.four, modifiers: [.control, .shift])
    ]
}

enum ShortcutSettings {
    private static let captureShortcutKey = "captureShortcut"
    static let defaultCaptureShortcutID = "cmd-shift-2"

    static var captureShortcut: ShortcutChoice {
        get {
            let id = UserDefaults.standard.string(forKey: captureShortcutKey) ?? defaultCaptureShortcutID
            return ShortcutChoice.all.first { $0.id == id } ?? ShortcutChoice.all[1]
        }
        set {
            UserDefaults.standard.set(newValue.id, forKey: captureShortcutKey)
        }
    }
}

extension NSEvent.ModifierFlags {
    init(hotKeyModifiers: HotKeyModifiers) {
        var flags: NSEvent.ModifierFlags = []
        if hotKeyModifiers.contains(.command) { flags.insert(.command) }
        if hotKeyModifiers.contains(.shift) { flags.insert(.shift) }
        if hotKeyModifiers.contains(.option) { flags.insert(.option) }
        if hotKeyModifiers.contains(.control) { flags.insert(.control) }
        self = flags
    }
}
