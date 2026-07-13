import AppKit

final class EditorWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?
    private let canvasView: EditorCanvasView

    init(image: NSImage) {
        canvasView = EditorCanvasView(image: image)
        let toolbar = EditorToolbarView(canvasView: canvasView)
        let stack = NSStackView(views: [toolbar, canvasView])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.distribution = .fill
        toolbar.heightAnchor.constraint(equalToConstant: 58).isActive = true

        let window = EditorWindow(
            contentRect: NSRect(x: 0, y: 0, width: max(760, image.size.width + 80), height: max(520, image.size.height + 120)),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Shotter Editor"
        window.contentView = stack
        window.initialFirstResponder = canvasView
        window.center()
        super.init(window: window)
        window.onQuickSave = { [weak self] in
            self?.canvasView.savePNGToDesktop(closeAfterSave: true)
        }
        window.canCopyImage = { [weak self] in
            guard let self else { return false }
            return !self.canvasView.isEditingText
        }
        window.onCopy = { [weak self] in
            self?.canvasView.copyToClipboard()
        }
        window.onCancel = { [weak self] in
            self?.canvasView.cancelEditingOrClose()
        }
        window.onUndo = { [weak self] in
            self?.canvasView.undoLastChange()
        }
        window.delegate = self
        canvasView.windowController = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}

private final class EditorWindow: NSWindow {
    var onQuickSave: (() -> Void)?
    var canCopyImage: (() -> Bool)?
    var onCopy: (() -> Void)?
    var onCancel: (() -> Void)?
    var onUndo: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func keyDown(with event: NSEvent) {
        if isUndoShortcut(event) {
            onUndo?()
        } else if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isUndoShortcut(event) {
            onUndo?()
            return true
        }
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "s" {
            onQuickSave?()
            return true
        }
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "c",
           canCopyImage?() == true {
            onCopy?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
