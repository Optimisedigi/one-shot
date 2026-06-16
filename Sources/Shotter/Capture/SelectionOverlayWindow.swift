import AppKit

final class SelectionOverlayController {
    private var windows: [SelectionOverlayWindow] = []
    private var completion: ((NSRect?) -> Void)?
    private var didPushCursor = false

    func begin(completion: @escaping (NSRect?) -> Void) {
        self.completion = completion
        NSApp.activate(ignoringOtherApps: true)
        windows = NSScreen.screens.map { screen in
            let window = SelectionOverlayWindow(screen: screen)
            window.selectionView.onFinish = { [weak self] rect in self?.finish(rect) }
            window.selectionView.onCancel = { [weak self] in self?.finish(nil) }
            return window
        }
        windows.forEach { window in
            window.orderFrontRegardless()
            window.selectionView.activateCrosshairCursor()
        }
        windows.first?.makeKey()
        pushCrosshairCursor()
        DispatchQueue.main.async { [weak self] in
            self?.pushCrosshairCursor()
            self?.windows.forEach { $0.selectionView.activateCrosshairCursor() }
        }
    }

    func cancel() {
        finish(nil)
    }

    private func finish(_ rect: NSRect?) {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        popCrosshairCursor()
        NSCursor.arrow.set()
        let handler = completion
        completion = nil
        handler?(rect)
    }

    private func pushCrosshairCursor() {
        guard !didPushCursor else {
            NSCursor.crosshair.set()
            return
        }
        NSCursor.crosshair.push()
        didPushCursor = true
    }

    private func popCrosshairCursor() {
        guard didPushCursor else { return }
        NSCursor.pop()
        didPushCursor = false
    }
}

final class SelectionOverlayWindow: NSPanel {
    let selectionView: SelectionOverlayView

    init(screen: NSScreen) {
        selectionView = SelectionOverlayView(screenFrame: screen.frame)
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
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
