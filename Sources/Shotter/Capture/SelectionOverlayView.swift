import AppKit

final class SelectionOverlayView: NSView {
    static let crosshairCursor: NSCursor = {
        let size = NSSize(width: 31, height: 31)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.5
        path.move(to: NSPoint(x: size.width / 2, y: 0))
        path.line(to: NSPoint(x: size.width / 2, y: size.height))
        path.move(to: NSPoint(x: 0, y: size.height / 2))
        path.line(to: NSPoint(x: size.width, y: size.height / 2))
        path.stroke()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        let highlight = NSBezierPath()
        highlight.lineWidth = 0.5
        highlight.move(to: NSPoint(x: size.width / 2 + 1.5, y: 0))
        highlight.line(to: NSPoint(x: size.width / 2 + 1.5, y: size.height))
        highlight.move(to: NSPoint(x: 0, y: size.height / 2 - 1.5))
        highlight.line(to: NSPoint(x: size.width, y: size.height / 2 - 1.5))
        highlight.stroke()
        image.unlockFocus()
        return NSCursor(image: image, hotSpot: NSPoint(x: size.width / 2, y: size.height / 2))
    }()
    var onFinish: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private let screenFrame: NSRect
    private let snapshotImage: NSImage?
    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?

    init(screenFrame: NSRect, snapshotImage: NSImage? = nil) {
        self.screenFrame = screenFrame
        self.snapshotImage = snapshotImage
        super.init(frame: NSRect(origin: .zero, size: screenFrame.size))
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
        activateCrosshairCursor()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: Self.crosshairCursor)
    }

    override func cursorUpdate(with event: NSEvent) {
        Self.crosshairCursor.set()
    }

    override func mouseMoved(with event: NSEvent) {
        Self.crosshairCursor.set()
    }

    func activateCrosshairCursor() {
        window?.invalidateCursorRects(for: self)
        window?.resetCursorRects()
        Self.crosshairCursor.set()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        guard let localRect = selectionRect, localRect.width > 1, localRect.height > 1 else {
            onCancel?()
            return
        }
        onFinish?(NSRect(
            x: screenFrame.minX + localRect.minX,
            y: screenFrame.minY + localRect.minY,
            width: localRect.width,
            height: localRect.height
        ))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        drawSnapshotBackground()

        guard let rect = selectionRect else {
            drawInstructionPill()
            return
        }

        NSColor.systemBlue.withAlphaComponent(0.9).setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        path.stroke()

        let label = "\(Int(rect.width)) × \(Int(rect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.65)
        ]
        label.draw(at: NSPoint(x: rect.minX + 6, y: rect.maxY + 6), withAttributes: attributes)
    }

    private func drawSnapshotBackground() {
        guard let snapshotImage else { return }
        snapshotImage.draw(in: bounds, from: NSRect(origin: .zero, size: snapshotImage.size), operation: .copy, fraction: 1)
    }

    private func drawInstructionPill() {
        let text = "Drag to capture • Esc to cancel"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attributes)
        let pill = NSRect(
            x: bounds.midX - (textSize.width + 28) / 2,
            y: bounds.maxY - textSize.height - 34,
            width: textSize.width + 28,
            height: textSize.height + 14
        )
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: pill, xRadius: 10, yRadius: 10).fill()
        text.draw(at: NSPoint(x: pill.minX + 14, y: pill.minY + 7), withAttributes: attributes)
    }

    private var selectionRect: NSRect? {
        guard let startPoint, let currentPoint else { return nil }
        return NSRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(startPoint.x - currentPoint.x),
            height: abs(startPoint.y - currentPoint.y)
        )
    }
}
