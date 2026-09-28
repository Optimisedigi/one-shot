import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotKeyManager: HotKeyManager?
    private var preferencesWindowController: PreferencesWindowController?
    private lazy var captureCoordinator = CaptureCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // SMAppService answers over synchronous XPC that can stall for seconds,
        // so the login-item repair runs off the main thread.
        DispatchQueue.global(qos: .utility).async {
            LaunchAtLoginSettings.syncWithSystem()
            // The setting promises the app opens at login; when macOS has not
            // enabled the item (usually pending approval), say so instead of
            // silently missing the next login.
            if LaunchAtLoginSettings.isDesired, LaunchAtLoginSettings.requiresApproval {
                NSAlert.showLoginItemsAlert(
                    message: "One Shot is waiting for approval to open at login",
                    informativeText: "macOS only opens apps at login after you approve them. Turn on One Shot under “Open at Login” in System Settings → General → Login Items, and One Shot will open automatically when you log in."
                )
            }
        }
        setupStatusItem()
        _ = setupHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager = nil
    }

    @objc func captureRegion() {
        captureCoordinator.startCapture()
    }

    @objc func openSettings() {
        if preferencesWindowController == nil {
            let controller = PreferencesWindowController()
            controller.onShortcutChanged = { [weak self] _, _ in
                guard let self else { return false }
                let registered = self.setupHotKey()
                self.refreshMenu()
                return registered
            }
            preferencesWindowController = controller
        }
        preferencesWindowController?.showWindow(nil)
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.title = ""
            button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "One Shot")
            button.image?.isTemplate = true
            button.toolTip = "One Shot"
        }
        item.menu = AppMenu.makeMenu(target: self)
        statusItem = item
    }

    private func setupHotKey() -> Bool {
        let shortcut = ShortcutSettings.captureShortcut
        let manager = HotKeyManager(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { [weak self] in
            NSLog("One Shot global hotkey fired: \(shortcut.title)")
            self?.captureRegion()
        }
        do {
            let oldManager = hotKeyManager
            try manager.register()
            oldManager?.unregister()
            hotKeyManager = manager
            NSLog("One Shot registered global hotkey: \(shortcut.title)")
            return true
        } catch {
            NSLog("One Shot failed to register global hotkey \(shortcut.title): \(error.localizedDescription)")
            NSAlert.show(message: "Could not register global hotkey", informativeText: "\(shortcut.title) may already be used by macOS or another app. Choose a different shortcut in Settings.\n\n\(error.localizedDescription)")
            return false
        }
    }

    private func refreshMenu() {
        statusItem?.menu = AppMenu.makeMenu(target: self)
    }
}
