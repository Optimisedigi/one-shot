import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotKeyManager: HotKeyManager?
    private var preferencesWindowController: PreferencesWindowController?
    private lazy var captureCoordinator = CaptureCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
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
            button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "Shotter")
            button.image?.isTemplate = true
            button.toolTip = "Shotter"
        }
        item.menu = AppMenu.makeMenu(target: self)
        statusItem = item
    }

    private func setupHotKey() -> Bool {
        let shortcut = ShortcutSettings.captureShortcut
        let manager = HotKeyManager(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { [weak self] in
            NSLog("Shotter global hotkey fired: \(shortcut.title)")
            self?.captureRegion()
        }
        do {
            let oldManager = hotKeyManager
            try manager.register()
            oldManager?.unregister()
            hotKeyManager = manager
            NSLog("Shotter registered global hotkey: \(shortcut.title)")
            return true
        } catch {
            NSLog("Shotter failed to register global hotkey \(shortcut.title): \(error.localizedDescription)")
            NSAlert.show(message: "Could not register global hotkey", informativeText: "\(shortcut.title) may already be used by macOS or another app. Choose a different shortcut in Settings.\n\n\(error.localizedDescription)")
            return false
        }
    }

    private func refreshMenu() {
        statusItem?.menu = AppMenu.makeMenu(target: self)
    }
}
