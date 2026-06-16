import AppKit

final class EditorCanvasView: NSView, NSTextFieldDelegate {
    weak var windowController: EditorWindowController?

    var tool: EditorTool = .rectangle {
        didSet { needsDisplay = true }
    }

    private var baseImage: NSImage
    private var annotations: [Annotation] = []
    private var undoStack: [[Annotation]] = []
    private var dragStartImagePoint: NSPoint?
    private var dragCurrentImagePoint: NSPoint?
    private var activeTextField: NSTextField?
    private var activeTextOrigin: NSPoint?
    private var selectedAnnotationIndex: Int? {
        didSet { onSelectionChange?(selectedAnnotationColor) }
    }
    private var movingTextIndex: Int?
    private var movingTextOffset: NSPoint = .zero
    private var zoom: CGFloat = 1

    var onSelectionChange: ((NSColor?) -> Void)?

    var selectedAnnotationColor: NSColor? {
        guard let selectedAnnotationIndex, annotations.indices.contains(selectedAnnotationIndex) else { return nil }
        return annotations[selectedAnnotationIndex].color
    }

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
        NSColor(calibratedWhite: 0.18, alpha: 1).setFill()
        bounds.fill()

        let rect = imageRect
        NSColor.black.withAlphaComponent(0.22).setFill()
        NSBezierPath(roundedRect: rect.insetBy(dx: -3, dy: -3).offsetBy(dx: 0, dy: -2), xRadius: 5, yRadius: 5).fill()
        baseImage.draw(in: rect, from: NSRect(origin: .zero, size: baseImage.size), operation: .sourceOver, fraction: 1)
        NSColor.separatorColor.setStroke()
        let imageOutline = NSBezierPath(rect: rect)
        imageOutline.lineWidth = 2
        imageOutline.stroke()

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
        if let annotationIndex = annotationIndex(at: point) {
            selectedAnnotationIndex = annotationIndex
            if tool == .text, case .text(_, let origin) = annotations[annotationIndex].kind {
                recordUndoState()
                movingTextIndex = annotationIndex
                movingTextOffset = NSPoint(x: point.x - origin.x, y: point.y - origin.y)
            }
            needsDisplay = true
            return
        }
        selectedAnnotationIndex = nil
        if tool == .text {
            beginInlineText(at: point)
            return
        }
        dragStartImagePoint = point
        dragCurrentImagePoint = point
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = imagePoint(from: event.locationInWindow, clamped: true)
        if let movingTextIndex {
            moveTextAnnotation(at: movingTextIndex, to: NSPoint(x: point.x - movingTextOffset.x, y: point.y - movingTextOffset.y))
        } else {
            dragCurrentImagePoint = point
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let movingTextIndex {
            selectedAnnotationIndex = movingTextIndex
            self.movingTextIndex = nil
            needsDisplay = true
            return
        }
        guard let start = dragStartImagePoint else { return }
        let end = imagePoint(from: event.locationInWindow, clamped: true)
        defer {
            dragStartImagePoint = nil
            dragCurrentImagePoint = nil
            needsDisplay = true
        }

        let rect = Geometry.normalizedRect(from: start, to: end)
        switch tool {
        case .rectangle where rect.width > 2 && rect.height > 2:
            recordUndoState()
            annotations.append(Annotation(kind: .rectangle(rect), lineWidth: 6))
            selectedAnnotationIndex = annotations.indices.last
        case .arrow where distance(start, end) > 2:
            recordUndoState()
            annotations.append(Annotation(kind: .arrow(start: start, end: end)))
            selectedAnnotationIndex = annotations.indices.last
        default:
            return
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "s" {
            commitActiveText()
            savePNGToDesktop(closeAfterSave: true)
        } else if isUndoShortcut(event) {
            undoLastChange()
        } else if event.keyCode == 53 {
            cancelEditingOrClose()
        } else if event.keyCode == 51, !annotations.isEmpty {
            deleteLastAnnotation()
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

    func cancelEditingOrClose() {
        if activeTextField != nil {
            commitActiveText()
        } else {
            window?.close()
        }
    }

    func undoLastChange() {
        commitActiveText()
        guard let previousAnnotations = undoStack.popLast() else { return }
        annotations = previousAnnotations
        selectedAnnotationIndex = annotations.indices.last
        needsDisplay = true
    }

    private func deleteLastAnnotation() {
        recordUndoState()
        annotations.removeLast()
        selectedAnnotationIndex = annotations.indices.last
        needsDisplay = true
    }

    private func recordUndoState() {
        undoStack.append(annotations)
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
        var rect = Geometry.aspectFitRect(imageSize: baseImage.size, in: bounds.insetBy(dx: 8, dy: 8))
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
        return imagePoint(fromViewPoint: point, in: rect)
    }

    private func imagePoint(from windowPoint: NSPoint, clamped: Bool) -> NSPoint {
        let point = convert(windowPoint, from: nil)
        let rect = imageRect
        guard clamped else { return imagePoint(fromViewPoint: point, in: rect) }
        let clampedPoint = NSPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
        return imagePoint(fromViewPoint: clampedPoint, in: rect)
    }

    private func imagePoint(fromViewPoint point: NSPoint, in rect: NSRect) -> NSPoint {
        NSPoint(
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
        for (index, annotation) in annotations.enumerated() {
            switch annotation.kind {
            case .rectangle(let rect):
                drawRectangle(rect, color: annotation.color, lineWidth: 6)
            case .arrow(let start, let end):
                drawArrow(start: start, end: end, color: annotation.color, lineWidth: annotation.lineWidth)
            case .text(let text, let origin):
                drawText(text, at: origin, color: annotation.color)
            }
            if index == selectedAnnotationIndex {
                drawSelectionHighlight(for: annotation)
            }
        }
    }

    private func beginInlineText(at imagePoint: NSPoint) {
        commitActiveText()
        let fieldOrigin = viewPoint(fromImagePoint: imagePoint)
        let field = EscapeCommittingTextField(frame: NSRect(x: fieldOrigin.x, y: fieldOrigin.y - 4, width: 280, height: 36))
        field.onEscape = { [weak self] in self?.commitActiveText() }
        field.isBordered = false
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.textColor = .systemRed
        field.font = .systemFont(ofSize: 28, weight: .bold)
        field.focusRingType = .none
        field.delegate = self
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

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        commitActiveText()
        return true
    }

    private func commitActiveText() {
        guard let field = activeTextField else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, let origin = activeTextOrigin {
            recordUndoState()
            annotations.append(Annotation(kind: .text(text, origin: origin)))
            selectedAnnotationIndex = annotations.indices.last
        }
        field.removeFromSuperview()
        activeTextField = nil
        activeTextOrigin = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    func applyColorToSelectedAnnotation(_ color: NSColor) {
        guard let selectedAnnotationIndex, annotations.indices.contains(selectedAnnotationIndex) else { return }
        recordUndoState()
        annotations[selectedAnnotationIndex].color = color
        onSelectionChange?(color)
        needsDisplay = true
    }

    private func annotationIndex(at point: NSPoint) -> Int? {
        annotations.indices.reversed().first { annotationHitTest(annotations[$0], at: point) }
    }

    private func annotationHitTest(_ annotation: Annotation, at point: NSPoint) -> Bool {
        switch annotation.kind {
        case .rectangle(let rect):
            return rect.insetBy(dx: -8, dy: -8).contains(point)
        case .arrow(let start, let end):
            return distanceFromPoint(point, toLineSegmentStart: start, end: end) <= 10
        case .text(let text, let origin):
            return textBounds(for: text, at: origin).contains(point)
        }
    }

    private func moveTextAnnotation(at index: Int, to origin: NSPoint) {
        guard annotations.indices.contains(index), case .text(let text, _) = annotations[index].kind else { return }
        annotations[index].kind = .text(text, origin: origin)
    }

    private func textBounds(for text: String, at origin: NSPoint) -> NSRect {
        let size = text.size(withAttributes: Self.textAttributes(color: .systemRed))
        return NSRect(x: origin.x, y: origin.y, width: size.width, height: size.height).insetBy(dx: -8, dy: -8)
    }

    private func drawSelectionHighlight(for annotation: Annotation) {
        NSColor.systemBlue.setStroke()
        switch annotation.kind {
        case .rectangle(let rect):
            drawDashedRect(rect.insetBy(dx: -6, dy: -6))
        case .arrow(let start, let end):
            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: end)
            path.lineWidth = 2
            path.setLineDash([6, 4], count: 2, phase: 0)
            path.stroke()
        case .text(let text, let origin):
            drawDashedRect(textBounds(for: text, at: origin))
        }
    }

    private func drawDashedRect(_ rect: NSRect) {
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        path.setLineDash([6, 4], count: 2, phase: 0)
        path.stroke()
    }

    class func textAttributes(color: NSColor) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: color,
            .strokeColor: NSColor.white,
            .strokeWidth: -2
        ]
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

func isUndoShortcut(_ event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    return event.charactersIgnoringModifiers?.lowercased() == "z" && (modifiers.contains(.control) || modifiers.contains(.command))
}

private func distanceFromPoint(_ point: NSPoint, toLineSegmentStart start: NSPoint, end: NSPoint) -> CGFloat {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let lengthSquared = dx * dx + dy * dy
    guard lengthSquared > 0 else { return distance(point, start) }

    let t = max(CGFloat(0), min(CGFloat(1), ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
    let projection = NSPoint(x: start.x + t * dx, y: start.y + t * dy)
    return distance(point, projection)
}

private final class EscapeCommittingTextField: NSTextField {
    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
