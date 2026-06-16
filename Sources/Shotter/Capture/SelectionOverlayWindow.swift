import AppKit

final class SelectionOverlayController {
    private var windows: [SelectionOverlayWindow] = []
    private var completion: ((NSRect?) -> Void)?
    private var didPushCursor = false
    private let snapshots: [ScreenSnapshot]

    init(snapshots: [ScreenSnapshot] = []) {
        self.snapshots = snapshots
    }

    func begin(completion: @escaping (NSRect?) -> Void) {
        self.completion = completion
        windows = NSScreen.screens.map { screen in
            let snapshot = snapshots.first { $0.screenFrame == screen.frame }
            let window = SelectionOverlayWindow(screen: screen, snapshotImage: snapshot?.image)
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

    init(screen: NSScreen, snapshotImage: NSImage? = nil) {
        selectionView = SelectionOverlayView(screenFrame: screen.frame, snapshotImage: snapshotImage)
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        animationBehavior = .none
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
