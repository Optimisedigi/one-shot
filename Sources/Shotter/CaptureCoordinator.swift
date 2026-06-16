import AppKit

final class CaptureCoordinator {
    private var overlayController: SelectionOverlayController?
    private var openEditors: [EditorWindowController] = []
    private let captureService = ScreenCaptureService()

    func startCapture(onFinish: (() -> Void)? = nil) {
        if let overlayController {
            overlayController.cancel()
            self.overlayController = nil
        }
        guard ScreenPermissionManager.ensurePermission() else {
            onFinish?()
            return
        }

        let snapshots: [ScreenSnapshot]
        do {
            snapshots = try captureService.captureScreens()
        } catch {
            NSAlert.show(message: "Screenshot failed", informativeText: error.localizedDescription)
            onFinish?()
            return
        }

        let controller = SelectionOverlayController(snapshots: snapshots)
        overlayController = controller
        controller.begin { [weak self] result in
            guard let self else { return }
            self.overlayController = nil
            guard let rect = result, rect.width >= 2, rect.height >= 2 else {
                onFinish?()
                return
            }
            defer { onFinish?() }
            do {
                let image = try self.captureService.crop(rect: rect, from: snapshots)
                self.openEditor(with: image)
            } catch {
                NSAlert.show(message: "Screenshot failed", informativeText: error.localizedDescription)
            }
        }
    }

    private func openEditor(with image: NSImage) {
        let editor = EditorWindowController(image: image)
        editor.onClose = { [weak self, weak editor] in
            guard let editor else { return }
            self?.openEditors.removeAll { $0 === editor }
        }
        openEditors.append(editor)
        NSApp.activate(ignoringOtherApps: true)
        editor.showWindow(nil)
        editor.window?.makeKeyAndOrderFront(nil)
    }
}
