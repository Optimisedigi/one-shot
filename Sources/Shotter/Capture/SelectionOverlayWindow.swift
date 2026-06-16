import AppKit

final class SelectionOverlayController {
    private var windows: [SelectionOverlayWindow] = []
    private var completion: ((NSRect?) -> Void)?

    func begin(completion: @escaping (NSRect?) -> Void) {
        self.completion = completion
        windows = NSScreen.screens.map { screen in
            let window = SelectionOverlayWindow(screen: screen)
            window.selectionView.onFinish = { [weak self] rect in self?.finish(rect) }
            window.selectionView.onCancel = { [weak self] in self?.finish(nil) }
            return window
        }
        windows.forEach { $0.orderFrontRegardless() }
        windows.first?.makeKey()
        NSCursor.crosshair.set()
    }

    func cancel() {
        finish(nil)
    }

    private func finish(_ rect: NSRect?) {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        NSCursor.arrow.set()
        let handler = completion
        completion = nil
        handler?(rect)
    }
}

final class SelectionOverlayWindow: NSPanel {
    let selectionView: SelectionOverlayView

    init(screen: NSScreen) {
        selectionView = SelectionOverlayView(screenFrame: screen.frame)
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = selectionView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
