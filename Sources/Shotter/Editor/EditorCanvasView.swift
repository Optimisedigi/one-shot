import AppKit

final class EditorCanvasView: NSView {
    weak var windowController: EditorWindowController?

    var tool: EditorTool = .rectangle {
        didSet { needsDisplay = true }
    }

    private var baseImage: NSImage
    private var annotations: [Annotation] = []
    private var dragStartImagePoint: NSPoint?
    private var dragCurrentImagePoint: NSPoint?
    private var activeTextField: NSTextField?
    private var activeTextOrigin: NSPoint?
    private var zoom: CGFloat = 1

    init(image: NSImage) {
        self.baseImage = image
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        let rect = imageRect
        baseImage.draw(in: rect, from: NSRect(origin: .zero, size: baseImage.size), operation: .sourceOver, fraction: 1)

        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.minX, yBy: rect.minY)
        transform.scaleX(by: rect.width / baseImage.size.width, yBy: rect.height / baseImage.size.height)
        transform.concat()
        drawAnnotations(annotations)
        drawPreview()
        NSGraphicsContext.restoreGraphicsState()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        commitActiveText()
        guard let point = imagePoint(from: event.locationInWindow) else { return }
        if tool == .text {
            beginInlineText(at: point)
            return
        }
        dragStartImagePoint = point
        dragCurrentImagePoint = point
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        dragCurrentImagePoint = imagePoint(from: event.locationInWindow)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStartImagePoint, let end = imagePoint(from: event.locationInWindow) else { return }
        defer {
            dragStartImagePoint = nil
            dragCurrentImagePoint = nil
            needsDisplay = true
        }

        let rect = Geometry.normalizedRect(from: start, to: end)
        switch tool {
        case .rectangle where rect.width > 2 && rect.height > 2:
            annotations.append(Annotation(kind: .rectangle(rect), lineWidth: 6))
        case .arrow where distance(start, end) > 2:
            annotations.append(Annotation(kind: .arrow(start: start, end: end)))
        default:
            return
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "s" {
            commitActiveText()
            savePNGToDesktop(closeAfterSave: true)
        } else if event.keyCode == 51, !annotations.isEmpty {
            annotations.removeLast()
            needsDisplay = true
        } else if event.charactersIgnoringModifiers == "+" || event.charactersIgnoringModifiers == "=" {
            zoom = min(zoom * 1.2, 6)
            needsDisplay = true
        } else if event.charactersIgnoringModifiers == "-" {
            zoom = max(zoom / 1.2, 0.2)
            needsDisplay = true
        } else if event.charactersIgnoringModifiers == "0" {
            zoom = 1
            needsDisplay = true
        } else {
            super.keyDown(with: event)
        }
    }

    func savePNG() {
        guard let window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Shotter Capture.png"
        commitActiveText()
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let data = self?.renderFinalImage().pngData() else { return }
            do {
                try data.write(to: url)
            } catch {
                NSAlert.show(message: "Save failed", informativeText: error.localizedDescription)
            }
        }
    }

    private var imageRect: NSRect {
        var rect = Geometry.aspectFitRect(imageSize: baseImage.size, in: bounds.insetBy(dx: 24, dy: 24))
        let center = NSPoint(x: rect.midX, y: rect.midY)
        rect.size.width *= zoom
        rect.size.height *= zoom
        rect.origin.x = center.x - rect.width / 2
        rect.origin.y = center.y - rect.height / 2
        return rect
    }

    private func imagePoint(from windowPoint: NSPoint) -> NSPoint? {
        let point = convert(windowPoint, from: nil)
        let rect = imageRect
        guard rect.contains(point) else { return nil }
        return NSPoint(
            x: ((point.x - rect.minX) / rect.width) * baseImage.size.width,
            y: ((point.y - rect.minY) / rect.height) * baseImage.size.height
        )
    }

    private func drawPreview() {
        guard let start = dragStartImagePoint, let current = dragCurrentImagePoint else { return }
        switch tool {
        case .rectangle:
            drawRectangle(Geometry.normalizedRect(from: start, to: current), color: .systemRed, lineWidth: 6)
        case .arrow:
            drawArrow(start: start, end: current, color: .systemRed, lineWidth: 4)
        case .text:
            break
        }
    }

    private func drawAnnotations(_ annotations: [Annotation]) {
        for annotation in annotations {
            switch annotation.kind {
            case .rectangle(let rect):
                drawRectangle(rect, color: annotation.color, lineWidth: 6)
            case .arrow(let start, let end):
                drawArrow(start: start, end: end, color: annotation.color, lineWidth: annotation.lineWidth)
            case .text(let text, let origin):
                drawText(text, at: origin, color: annotation.color)
            }
        }
    }

    private func beginInlineText(at imagePoint: NSPoint) {
        commitActiveText()
        let fieldOrigin = viewPoint(fromImagePoint: imagePoint)
        let field = NSTextField(frame: NSRect(x: fieldOrigin.x, y: fieldOrigin.y - 4, width: 280, height: 36))
        field.isBordered = false
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.textColor = .systemRed
        field.font = .systemFont(ofSize: 28, weight: .bold)
        field.focusRingType = .none
        field.target = self
        field.action = #selector(commitActiveTextAction)
        addSubview(field)
        activeTextField = field
        activeTextOrigin = imagePoint
        window?.makeFirstResponder(field)
    }

    @objc private func commitActiveTextAction() {
        commitActiveText()
    }

    private func commitActiveText() {
        guard let field = activeTextField else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, let origin = activeTextOrigin {
            annotations.append(Annotation(kind: .text(text, origin: origin)))
        }
        field.removeFromSuperview()
        activeTextField = nil
        activeTextOrigin = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    func savePNGToDesktop(closeAfterSave: Bool = false) {
        commitActiveText()
        guard let data = renderFinalImage().pngData() else { return }
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser
        let fileName = "Shotter Capture \(Self.fileTimestamp()).png"
        let url = desktopURL.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            if closeAfterSave {
                window?.close()
            }
        } catch {
            NSAlert.show(message: "Save failed", informativeText: error.localizedDescription)
        }
    }

    private static func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: Date())
    }

    private func viewPoint(fromImagePoint point: NSPoint) -> NSPoint {
        let rect = imageRect
        return NSPoint(
            x: rect.minX + (point.x / baseImage.size.width) * rect.width,
            y: rect.minY + (point.y / baseImage.size.height) * rect.height
        )
    }

    private func renderFinalImage() -> NSImage {
        ImageRenderer.render(baseImage: baseImage, annotations: annotations)
    }
}

private func distance(_ a: NSPoint, _ b: NSPoint) -> CGFloat {
    hypot(a.x - b.x, a.y - b.y)
}
