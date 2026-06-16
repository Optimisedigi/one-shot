import AppKit

final class PreferencesWindowController: NSWindowController {
    var onShortcutChanged: ((ShortcutChoice, ShortcutChoice) -> Bool)?
    private let shortcutPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let launchAtLoginButton = NSButton(checkboxWithTitle: "Open Shotter at login", target: nil, action: nil)

    init() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 190))
        let window = NSWindow(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Shotter Settings"
        window.contentView = contentView
        super.init(window: window)
        setupContent(in: contentView)
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupContent(in contentView: NSView) {
        let titleLabel = NSTextField(labelWithString: "Capture Region shortcut")
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let helperLabel = NSTextField(wrappingLabelWithString: "Pick a global hotkey. If you choose Apple’s built-in ⌘⇧4 or ⌘⇧5, disable or change that shortcut in macOS Keyboard Shortcuts first.")
        helperLabel.font = .systemFont(ofSize: 12)
        helperLabel.textColor = .secondaryLabelColor
        helperLabel.translatesAutoresizingMaskIntoConstraints = false

        shortcutPopup.translatesAutoresizingMaskIntoConstraints = false
        shortcutPopup.target = self
        shortcutPopup.action = #selector(shortcutChanged)
        for choice in ShortcutChoice.all {
            shortcutPopup.addItem(withTitle: choice.title)
            shortcutPopup.lastItem?.representedObject = choice.id
        }
        selectCurrentShortcut()

        launchAtLoginButton.translatesAutoresizingMaskIntoConstraints = false
        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(launchAtLoginChanged)
        launchAtLoginButton.state = LaunchAtLoginSettings.isEnabled ? .on : .off

        contentView.addSubview(titleLabel)
        contentView.addSubview(shortcutPopup)
        contentView.addSubview(helperLabel)
        contentView.addSubview(launchAtLoginButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),

            shortcutPopup.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 16),
            shortcutPopup.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            shortcutPopup.widthAnchor.constraint(equalToConstant: 120),

            helperLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            helperLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            helperLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 18),

            launchAtLoginButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            launchAtLoginButton.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),
            launchAtLoginButton.topAnchor.constraint(equalTo: helperLabel.bottomAnchor, constant: 24)
        ])
    }

    private func selectCurrentShortcut() {
        let currentID = ShortcutSettings.captureShortcut.id
        if let item = shortcutPopup.itemArray.first(where: { $0.representedObject as? String == currentID }) {
            shortcutPopup.select(item)
        }
    }

    @objc private func shortcutChanged() {
        guard let id = shortcutPopup.selectedItem?.representedObject as? String,
              let choice = ShortcutChoice.all.first(where: { $0.id == id }) else { return }
        let previous = ShortcutSettings.captureShortcut
        guard choice != previous else { return }
        ShortcutSettings.captureShortcut = choice
        if onShortcutChanged?(previous, choice) == false {
            ShortcutSettings.captureShortcut = previous
            selectCurrentShortcut()
        }
    }

    @objc private func launchAtLoginChanged() {
        let shouldEnable = launchAtLoginButton.state == .on
        do {
            try LaunchAtLoginSettings.setEnabled(shouldEnable)
            launchAtLoginButton.state = LaunchAtLoginSettings.isEnabled ? .on : .off
        } catch {
            launchAtLoginButton.state = LaunchAtLoginSettings.isEnabled ? .on : .off
            NSAlert.show(message: "Could not update startup setting", informativeText: error.localizedDescription)
        }
    }
}
