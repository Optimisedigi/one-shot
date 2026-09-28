import AppKit
import ServiceManagement

enum AppMenu {
    static func makeMenu(target: AnyObject) -> NSMenu {
        let shortcut = ShortcutSettings.captureShortcut
        let menu = NSMenu()

        let captureItem = NSMenuItem(title: "Capture Region", action: #selector(AppDelegate.captureRegion), keyEquivalent: shortcut.keyEquivalent)
        captureItem.keyEquivalentModifierMask = NSEvent.ModifierFlags(hotKeyModifiers: shortcut.modifiers)
        captureItem.target = target
        menu.addItem(captureItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(AppDelegate.openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = target
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Shotter", action: #selector(AppDelegate.quit), keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)
        return menu
    }
}

extension NSAlert {
    static func show(message: String, informativeText: String = "") {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            alert.informativeText = informativeText
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    /// Alert with a shortcut to System Settings → Login Items, the one place
    /// macOS lets users approve (or block) apps that open at login. Safe to
    /// call from any thread.
    static func showLoginItemsAlert(message: String, informativeText: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            alert.informativeText = informativeText
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Login Items Settings")
            alert.addButton(withTitle: "Later")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }
}
