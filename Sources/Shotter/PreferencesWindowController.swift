import AppKit

final class PreferencesWindowController: NSWindowController {
    var onShortcutChanged: ((ShortcutChoice, ShortcutChoice) -> Bool)?
    private let shortcutPopup = NSPopUpButton(frame: .zero, pullsDown: false)

    init() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 140))
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

        contentView.addSubview(titleLabel)
        contentView.addSubview(shortcutPopup)
        contentView.addSubview(helperLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),

            shortcutPopup.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 16),
            shortcutPopup.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            shortcutPopup.widthAnchor.constraint(equalToConstant: 120),

            helperLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            helperLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            helperLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 18)
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
}
