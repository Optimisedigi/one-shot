import AppKit

final class EditorCanvasView: NSView {
    private static let resizeDragSensitivity: CGFloat = 0.35

    weak var windowController: EditorWindowController?

    var tool: EditorTool = .rectangle {
        didSet { needsDisplay = true }
    }

    private var baseImage: NSImage
    private var annotations: [Annotation] = []
    private var undoStack: [[Annotation]] = []
    private enum DragMode {
        case drawing(start: NSPoint, current: NSPoint)
        case moving(index: Int, offset: NSPoint)
        case resizing(index: Int, handle: ResizeHandle, originalBounds: NSRect)
    }

    private enum ResizeHandle: CaseIterable {
        case bottomLeft
        case bottomRight
        case topLeft
        case topRight
    }

    private struct PixelateCacheKey: Hashable {
        let minX: CGFloat
        let minY: CGFloat
        let width: CGFloat
        let height: CGFloat
        let scale: CGFloat
    }

    private var dragMode: DragMode?
    private var pixelateCache: [PixelateCacheKey: NSImage] = [:]
    private var activeTextView: MultilineCommittingTextView?
    private var activeTextOrigin: NSPoint?
    private var selectedAnnotationIndex: Int? {
        didSet { onSelectionChange?(selectedAnnotationColor, selectedAnnotationBorderColor, selectedAnnotationWeight) }
    }
    private var zoom: CGFloat = 1
    private var activeNumberField: NSTextField?
    private var activeNumberFieldIndex: Int?
    private static let stepNumberHitFraction: CGFloat = 0.55

    var onSelectionChange: ((NSColor?, NSColor?, CGFloat?) -> Void)?

    var selectedAnnotationColor: NSColor? {
        guard let selectedAnnotationIndex, annotations.indices.contains(selectedAnnotationIndex) else { return nil }
        return annotations[selectedAnnotationIndex].color
    }

    var selectedAnnotationBorderColor: NSColor? {
        guard let selectedAnnotationIndex, annotations.indices.contains(selectedAnnotationIndex) else { return nil }
        let annotation = annotations[selectedAnnotationIndex]
        return annotation.isStep ? annotation.borderColor : nil
    }

    var selectedAnnotationWeight: CGFloat? {
        guard let selectedAnnotationIndex, annotations.indices.contains(selectedAnnotationIndex) else { return nil }
        return weight(for: annotations[selectedAnnotationIndex])
    }

    var isEditingText: Bool {
        activeTextView != nil
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
        commitActiveNumberEdit(apply: true)
        guard let point = imagePoint(from: event.locationInWindow) else { return }
        if let handleHit = resizeHandleHit(at: point) {
            recordUndoState()
            selectedAnnotationIndex = handleHit.index
            dragMode = .resizing(index: handleHit.index, handle: handleHit.handle, originalBounds: annotationBounds(annotations[handleHit.index]))
            needsDisplay = true
            return
        }
        if let annotationIndex = annotationIndex(at: point) {
            let annotation = annotations[annotationIndex]
            // Pressing the number glyph inside a Step badge is an independent
            // interaction from selecting/moving the badge's border: it only
            // opens the number for editing and never starts a drag, so it
            // can't be mistaken for (or trigger) a border selection.
            if annotation.isStep, stepNumberHitTest(annotation, at: point) {
                beginNumberEdit(at: annotationIndex)
                return
            }
            if tool == .text, !annotation.isText {
                selectedAnnotationIndex = nil
                beginInlineText(at: point)
                return
            }
            selectedAnnotationIndex = annotationIndex
            recordUndoState()
            dragMode = .moving(index: annotationIndex, offset: moveOffset(for: annotation, at: point))
            needsDisplay = true
            return
        }
        selectedAnnotationIndex = nil
        if tool == .text {
            beginInlineText(at: point)
            return
        }
        if tool == .step {
            placeStep(at: point)
            return
        }
        dragMode = .drawing(start: point, current: point)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = imagePoint(from: event.locationInWindow, clamped: true)
        switch dragMode {
        case .drawing(let start, _):
            dragMode = .drawing(start: start, current: point)
        case .moving(let index, let offset):
            moveAnnotation(at: index, to: point, offset: offset)
        case .resizing(let index, let handle, let originalBounds):
            resizeAnnotation(at: index, handle: handle, originalBounds: originalBounds, to: point)
            onSelectionChange?(selectedAnnotationColor, selectedAnnotationBorderColor, selectedAnnotationWeight)
        case nil:
            break
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let dragMode else { return }
        defer {
            self.dragMode = nil
            needsDisplay = true
        }

        switch dragMode {
        case .drawing(let start, _):
            let end = imagePoint(from: event.locationInWindow, clamped: true)
            let rect = Geometry.normalizedRect(from: start, to: end)
            switch tool {
            case .rectangle where rect.width > 2 && rect.height > 2:
                recordUndoState()
                annotations.append(Annotation(kind: .rectangle(rect), lineWidth: Annotation.defaultRectangleLineWidth))
                selectedAnnotationIndex = annotations.indices.last
            case .arrow where distance(start, end) > 2:
                recordUndoState()
                annotations.append(Annotation(kind: .arrow(start: start, end: end), lineWidth: Annotation.defaultArrowLineWidth))
                selectedAnnotationIndex = annotations.indices.last
            case .pixelate where rect.width > 2 && rect.height > 2:
                recordUndoState()
                annotations.append(Annotation(kind: .pixelate(rect), lineWidth: Annotation.defaultPixelBlockScale))
                selectedAnnotationIndex = annotations.indices.last
            default:
                return
            }
        case .moving(let index, _), .resizing(let index, _, _):
            selectedAnnotationIndex = index
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "s" {
            commitActiveText()
            savePNGToDesktop(closeAfterSave: true)
        } else if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "c", activeTextView == nil {
            copyToClipboard()
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
        if activeTextView != nil {
            commitActiveText()
        } else {
            window?.close()
        }
    }

    func undoLastChange() {
        commitActiveText()
        guard let previousAnnotations = undoStack.popLast() else { return }
        pixelateCache.removeAll()
        annotations = previousAnnotations
        selectedAnnotationIndex = annotations.indices.last
        needsDisplay = true
    }

    private func deleteLastAnnotation() {
        recordUndoState()
        annotations.removeLast()
        pixelateCache.removeAll()
        selectedAnnotationIndex = annotations.indices.last
        needsDisplay = true
    }

    private func recordUndoState() {
        pixelateCache.removeAll()
        undoStack.append(annotations)
    }

    func copyToClipboard() {
        commitActiveText()
        renderFinalImage().copyToPasteboard()
    }

    func savePNG() {
        guard let window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "SC.png"
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
        guard case .drawing(let start, let current) = dragMode else { return }
        switch tool {
        case .rectangle:
            drawRectangle(Geometry.normalizedRect(from: start, to: current), color: .systemRed, lineWidth: Annotation.defaultRectangleLineWidth)
        case .arrow:
            drawArrow(start: start, end: current, color: .systemRed, lineWidth: Annotation.defaultArrowLineWidth)
        case .text:
            break
        case .pixelate:
            let rect = Geometry.normalizedRect(from: start, to: current)
            NSColor.systemRed.withAlphaComponent(0.18).setFill()
            rect.fill()
            drawRectangle(rect, color: .systemRed, lineWidth: Annotation.defaultRectangleLineWidth)
        case .step:
            break
        }
    }

    private func drawAnnotations(_ annotations: [Annotation]) {
        for (index, annotation) in annotations.enumerated() {
            switch annotation.kind {
            case .rectangle(let rect):
                drawRectangle(rect, color: annotation.color, lineWidth: annotation.lineWidth)
            case .arrow(let start, let end):
                drawArrow(start: start, end: end, color: annotation.color, lineWidth: annotation.lineWidth)
            case .text(let text, let origin, let fontSize):
                drawText(text, at: origin, color: annotation.color, fontSize: fontSize)
            case .pixelate(let rect):
                drawCachedPixelate(rect, scale: annotation.lineWidth)
            case .step(let number, let center, let radius):
                drawStep(number: number, center: center, radius: radius, color: annotation.color, borderColor: annotation.borderColor)
            }
            if index == selectedAnnotationIndex {
                drawSelectionHighlight(for: annotation)
            }
        }
    }

    private func placeStep(at imagePoint: NSPoint) {
        recordUndoState()
        annotations.append(Annotation(kind: .step(number: nextStepNumber(), center: imagePoint, radius: Annotation.defaultStepRadius)))
        selectedAnnotationIndex = annotations.indices.last
        needsDisplay = true
    }

    private func nextStepNumber() -> Int {
        annotations.filter { annotation in
            if case .step = annotation.kind { return true }
            return false
        }.count + 1
    }

    /// True when `point` lands on the inner number glyph of a Step badge,
    /// as opposed to the outer ring/border used to select or drag it.
    private func stepNumberHitTest(_ annotation: Annotation, at point: NSPoint) -> Bool {
        guard case .step(_, let center, let radius) = annotation.kind else { return false }
        return distance(point, center) <= radius * Self.stepNumberHitFraction
    }

    private func beginNumberEdit(at index: Int) {
        commitActiveText()
        commitActiveNumberEdit(apply: true)
        guard annotations.indices.contains(index), case .step(let number, let center, let radius) = annotations[index].kind else { return }
        selectedAnnotationIndex = nil
        let viewCenter = viewPoint(fromImagePoint: center)
        let viewRadius = radius * (imageRect.width / max(baseImage.size.width, 1))
        let size = max(26, viewRadius * 1.3)
        let field = NSTextField(frame: NSRect(x: viewCenter.x - size / 2, y: viewCenter.y - size / 2, width: size, height: size))
        field.stringValue = String(number)
        field.alignment = .center
        field.font = .systemFont(ofSize: 14, weight: .bold)
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = true
        field.backgroundColor = .white
        field.textColor = .black
        field.wantsLayer = true
        field.layer?.cornerRadius = size / 2
        field.layer?.masksToBounds = true
        field.delegate = self
        addSubview(field)
        activeNumberField = field
        activeNumberFieldIndex = index
        window?.makeFirstResponder(field)
        field.currentEditor()?.selectAll(nil)
    }

    private func commitActiveNumberEdit(apply: Bool) {
        guard let field = activeNumberField, let index = activeNumberFieldIndex else { return }
        activeNumberField = nil
        activeNumberFieldIndex = nil
        defer {
            field.removeFromSuperview()
            if window?.firstResponder === field.currentEditor() { window?.makeFirstResponder(self) }
            needsDisplay = true
        }
        guard apply, annotations.indices.contains(index), case .step(_, let center, let radius) = annotations[index].kind else { return }
        if let newNumber = Int(field.stringValue.trimmingCharacters(in: .whitespaces)), newNumber > 0 {
            recordUndoState()
            annotations[index].kind = .step(number: newNumber, center: center, radius: radius)
            selectedAnnotationIndex = index
        }
    }

    private func drawCachedPixelate(_ rect: NSRect, scale: CGFloat) {
        let key = PixelateCacheKey(minX: rect.minX, minY: rect.minY, width: rect.width, height: rect.height, scale: scale)
        if let image = pixelateCache[key] {
            image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
            return
        }
        if let image = PixelateRenderer.pixelatedImage(from: baseImage, rect: rect, scale: scale) {
            pixelateCache[key] = image
            image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
        } else {
            NSColor.black.withAlphaComponent(0.85).setFill()
            rect.fill()
        }
    }

    private func beginInlineText(at imagePoint: NSPoint) {
        commitActiveText()
        let fieldOrigin = viewPoint(fromImagePoint: imagePoint)
        let textView = MultilineCommittingTextView(frame: NSRect(x: fieldOrigin.x, y: fieldOrigin.y - 4, width: 280, height: 112))
        textView.onEscape = { [weak self] in self?.commitActiveText() }
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: textView.bounds.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = .zero
        textView.textColor = .systemRed
        textView.insertionPointColor = .systemRed
        textView.font = .systemFont(ofSize: Annotation.defaultTextFontSize, weight: .bold)
        addSubview(textView)
        activeTextView = textView
        activeTextOrigin = imagePoint
        window?.makeFirstResponder(textView)
    }

    private func commitActiveText() {
        guard let textView = activeTextView else { return }
        let text = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, let origin = activeTextOrigin {
            recordUndoState()
            annotations.append(Annotation(kind: .text(text, origin: origin, fontSize: Annotation.defaultTextFontSize)))
            selectedAnnotationIndex = annotations.indices.last
        }
        textView.removeFromSuperview()
        activeTextView = nil
        activeTextOrigin = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    func applyColorToSelectedAnnotation(_ color: NSColor) {
        guard let selectedAnnotationIndex, annotations.indices.contains(selectedAnnotationIndex) else { return }
        recordUndoState()
        annotations[selectedAnnotationIndex].color = color
        onSelectionChange?(color, selectedAnnotationBorderColor, selectedAnnotationWeight)
        needsDisplay = true
    }

    func applyBorderColorToSelectedAnnotation(_ color: NSColor) {
        guard let selectedAnnotationIndex, annotations.indices.contains(selectedAnnotationIndex),
              annotations[selectedAnnotationIndex].isStep else { return }
        recordUndoState()
        annotations[selectedAnnotationIndex].borderColor = color
        onSelectionChange?(selectedAnnotationColor, color, selectedAnnotationWeight)
        needsDisplay = true
    }

    func applyWeightToSelectedAnnotation(_ weight: CGFloat) {
        guard let selectedAnnotationIndex, annotations.indices.contains(selectedAnnotationIndex) else { return }
        recordUndoState()
        switch annotations[selectedAnnotationIndex].kind {
        case .rectangle, .arrow:
            annotations[selectedAnnotationIndex].lineWidth = clamp(weight, min: Annotation.minimumLineWidth, max: Annotation.maximumLineWidth)
        case .pixelate:
            annotations[selectedAnnotationIndex].lineWidth = clamp(weight, min: Annotation.minimumPixelBlockScale, max: Annotation.maximumPixelBlockScale)
        case .text(let text, let origin, _):
            annotations[selectedAnnotationIndex].kind = .text(text, origin: origin, fontSize: clamp(weight, min: Annotation.minimumTextFontSize, max: Annotation.maximumTextFontSize))
        case .step(let number, let center, _):
            annotations[selectedAnnotationIndex].kind = .step(number: number, center: center, radius: clamp(weight, min: Annotation.minimumStepRadius, max: Annotation.maximumStepRadius))
        }
        onSelectionChange?(selectedAnnotationColor, selectedAnnotationBorderColor, selectedAnnotationWeight)
        needsDisplay = true
    }

    private func weight(for annotation: Annotation) -> CGFloat {
        switch annotation.kind {
        case .rectangle, .arrow, .pixelate:
            return annotation.lineWidth
        case .text(_, _, let fontSize):
            return fontSize
        case .step(_, _, let radius):
            return radius
        }
    }

    private func annotationIndex(at point: NSPoint) -> Int? {
        annotations.indices.reversed().first { annotationHitTest(annotations[$0], at: point) }
    }

    private func annotationBounds(_ annotation: Annotation) -> NSRect {
        switch annotation.kind {
        case .rectangle(let rect), .pixelate(let rect):
            return rect
        case .arrow(let start, let end):
            return Geometry.normalizedRect(from: start, to: end)
        case .text(let text, let origin, let fontSize):
            return textBounds(for: text, at: origin, fontSize: fontSize)
        case .step(_, let center, let radius):
            return stepBounds(center: center, radius: radius)
        }
    }

    private func annotationHitTest(_ annotation: Annotation, at point: NSPoint) -> Bool {
        switch annotation.kind {
        case .rectangle(let rect), .pixelate(let rect):
            return rect.insetBy(dx: -8, dy: -8).contains(point)
        case .arrow(let start, let end):
            return distanceFromPoint(point, toLineSegmentStart: start, end: end) <= 10
        case .text(let text, let origin, let fontSize):
            return textBounds(for: text, at: origin, fontSize: fontSize).contains(point)
        case .step(_, let center, let radius):
            return distance(point, center) <= radius + 4
        }
    }

    private func moveAnnotation(at index: Int, to point: NSPoint, offset: NSPoint) {
        guard annotations.indices.contains(index) else { return }
        let origin = NSPoint(x: point.x - offset.x, y: point.y - offset.y)
        let annotation = annotations[index]
        switch annotation.kind {
        case .rectangle(let rect):
            annotations[index].kind = .rectangle(NSRect(origin: origin, size: rect.size))
        case .pixelate(let rect):
            annotations[index].kind = .pixelate(NSRect(origin: origin, size: rect.size))
        case .arrow(let start, let end):
            let delta = NSPoint(x: origin.x - start.x, y: origin.y - start.y)
            annotations[index].kind = .arrow(start: origin, end: NSPoint(x: end.x + delta.x, y: end.y + delta.y))
        case .text(let text, _, let fontSize):
            annotations[index].kind = .text(text, origin: origin, fontSize: fontSize)
        case .step(let number, _, let radius):
            annotations[index].kind = .step(number: number, center: NSPoint(x: origin.x + radius, y: origin.y + radius), radius: radius)
        }
    }

    private func moveOffset(for annotation: Annotation, at point: NSPoint) -> NSPoint {
        let origin = annotationMoveOrigin(annotation)
        return NSPoint(x: point.x - origin.x, y: point.y - origin.y)
    }

    private func annotationMoveOrigin(_ annotation: Annotation) -> NSPoint {
        switch annotation.kind {
        case .rectangle(let rect), .pixelate(let rect):
            return rect.origin
        case .arrow(let start, _):
            return start
        case .text(_, let origin, _):
            return origin
        case .step(_, let center, let radius):
            return NSPoint(x: center.x - radius, y: center.y - radius)
        }
    }

    private func textBounds(for text: String, at origin: NSPoint, fontSize: CGFloat) -> NSRect {
        let size = Self.textSize(text, fontSize: fontSize)
        return NSRect(x: origin.x, y: origin.y, width: size.width, height: size.height).insetBy(dx: -8, dy: -8)
    }

    private func stepBounds(center: NSPoint, radius: CGFloat) -> NSRect {
        NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    private func resizeHandleHit(at point: NSPoint) -> (index: Int, handle: ResizeHandle)? {
        guard let selectedAnnotationIndex, annotations.indices.contains(selectedAnnotationIndex) else { return nil }
        guard annotations[selectedAnnotationIndex].isResizable else { return nil }
        let bounds = annotationBounds(annotations[selectedAnnotationIndex])
        return ResizeHandle.allCases.first { handleRect(for: $0, in: bounds).contains(point) }.map { (selectedAnnotationIndex, $0) }
    }

    private func handleRect(for handle: ResizeHandle, in rect: NSRect) -> NSRect {
        let center: NSPoint
        switch handle {
        case .bottomLeft:
            center = NSPoint(x: rect.minX, y: rect.minY)
        case .bottomRight:
            center = NSPoint(x: rect.maxX, y: rect.minY)
        case .topLeft:
            center = NSPoint(x: rect.minX, y: rect.maxY)
        case .topRight:
            center = NSPoint(x: rect.maxX, y: rect.maxY)
        }
        return NSRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)
    }

    private func resizeAnnotation(at index: Int, handle: ResizeHandle, originalBounds: NSRect, to point: NSPoint) {
        guard annotations.indices.contains(index) else { return }
        let anchor = anchorPoint(opposite: handle, in: originalBounds)
        let originalDistance = distance(anchor, cornerPoint(handle, in: originalBounds))
        guard originalDistance > 0 else { return }
        let rawScale = max(0.1, distance(anchor, point) / originalDistance)
        let scale = resizeScale(from: rawScale)
        switch annotations[index].kind {
        case .rectangle:
            let width = max(2, originalBounds.width * scale)
            let height = max(2, originalBounds.height * scale)
            let rect = rectFrom(anchor: anchor, handle: handle, size: NSSize(width: width, height: height))
            annotations[index].kind = .rectangle(rect)
        case .pixelate:
            let width = max(2, originalBounds.width * scale)
            let height = max(2, originalBounds.height * scale)
            let rect = rectFrom(anchor: anchor, handle: handle, size: NSSize(width: width, height: height))
            annotations[index].kind = .pixelate(rect)
        case .text(let text, _, let fontSize):
            let newFontSize = clamp(fontSize * scale, min: Annotation.minimumTextFontSize, max: Annotation.maximumTextFontSize)
            let newBounds = textBounds(for: text, at: originalBounds.origin, fontSize: newFontSize)
            let newOrigin = textOriginForResize(handle: handle, originalBounds: originalBounds, newBounds: newBounds)
            annotations[index].kind = .text(text, origin: newOrigin, fontSize: newFontSize)
        case .step(let number, _, let radius):
            let newRadius = clamp(radius * scale, min: Annotation.minimumStepRadius, max: Annotation.maximumStepRadius)
            let newBounds = rectFrom(anchor: anchor, handle: handle, size: NSSize(width: newRadius * 2, height: newRadius * 2))
            annotations[index].kind = .step(number: number, center: NSPoint(x: newBounds.midX, y: newBounds.midY), radius: newRadius)
        case .arrow:
            break
        }
    }

    private func resizeScale(from rawScale: CGFloat) -> CGFloat {
        1 + ((rawScale - 1) * Self.resizeDragSensitivity)
    }

    private func anchorPoint(opposite handle: ResizeHandle, in rect: NSRect) -> NSPoint {
        switch handle {
        case .bottomLeft:
            return NSPoint(x: rect.maxX, y: rect.maxY)
        case .bottomRight:
            return NSPoint(x: rect.minX, y: rect.maxY)
        case .topLeft:
            return NSPoint(x: rect.maxX, y: rect.minY)
        case .topRight:
            return NSPoint(x: rect.minX, y: rect.minY)
        }
    }

    private func cornerPoint(_ handle: ResizeHandle, in rect: NSRect) -> NSPoint {
        switch handle {
        case .bottomLeft:
            return NSPoint(x: rect.minX, y: rect.minY)
        case .bottomRight:
            return NSPoint(x: rect.maxX, y: rect.minY)
        case .topLeft:
            return NSPoint(x: rect.minX, y: rect.maxY)
        case .topRight:
            return NSPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    private func textOriginForResize(handle: ResizeHandle, originalBounds: NSRect, newBounds: NSRect) -> NSPoint {
        switch handle {
        case .bottomLeft:
            return NSPoint(x: originalBounds.maxX - newBounds.width + 8, y: originalBounds.maxY - newBounds.height + 8)
        case .bottomRight:
            return NSPoint(x: originalBounds.minX + 8, y: originalBounds.maxY - newBounds.height + 8)
        case .topLeft:
            return NSPoint(x: originalBounds.maxX - newBounds.width + 8, y: originalBounds.minY + 8)
        case .topRight:
            return NSPoint(x: originalBounds.minX + 8, y: originalBounds.minY + 8)
        }
    }

    private func rectFrom(anchor: NSPoint, handle: ResizeHandle, size: NSSize) -> NSRect {
        switch handle {
        case .bottomLeft:
            return NSRect(x: anchor.x - size.width, y: anchor.y - size.height, width: size.width, height: size.height)
        case .bottomRight:
            return NSRect(x: anchor.x, y: anchor.y - size.height, width: size.width, height: size.height)
        case .topLeft:
            return NSRect(x: anchor.x - size.width, y: anchor.y, width: size.width, height: size.height)
        case .topRight:
            return NSRect(origin: anchor, size: size)
        }
    }

    private func drawSelectionHighlight(for annotation: Annotation) {
        NSColor.systemBlue.setStroke()
        switch annotation.kind {
        case .rectangle(let rect):
            drawDashedRect(rect.insetBy(dx: -6, dy: -6))
            drawResizeHandles(for: rect)
        case .pixelate(let rect):
            drawDashedRect(rect.insetBy(dx: -6, dy: -6))
            drawResizeHandles(for: rect)
        case .arrow(let start, let end):
            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: end)
            path.lineWidth = 2
            path.setLineDash([6, 4], count: 2, phase: 0)
            path.stroke()
        case .text(let text, let origin, let fontSize):
            drawDashedRect(textBounds(for: text, at: origin, fontSize: fontSize))
            drawResizeHandles(for: textBounds(for: text, at: origin, fontSize: fontSize))
        case .step(_, let center, let radius):
            let bounds = stepBounds(center: center, radius: radius)
            let path = NSBezierPath(ovalIn: bounds.insetBy(dx: -6, dy: -6))
            path.lineWidth = 2
            path.setLineDash([6, 4], count: 2, phase: 0)
            path.stroke()
            drawResizeHandles(for: bounds)
        }
    }

    private func drawDashedRect(_ rect: NSRect) {
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        path.setLineDash([6, 4], count: 2, phase: 0)
        path.stroke()
    }

    private func drawResizeHandles(for rect: NSRect) {
        NSColor.white.setFill()
        NSColor.systemBlue.setStroke()
        for handle in ResizeHandle.allCases {
            let handleRect = handleRect(for: handle, in: rect)
            let path = NSBezierPath(rect: handleRect)
            path.fill()
            path.lineWidth = 1.5
            path.stroke()
        }
    }

    class func textAttributes(color: NSColor, fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: color
        ]
    }

    class func textSize(_ text: String, fontSize: CGFloat) -> NSSize {
        let bounds = text.boundingRect(
            with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: textAttributes(color: .systemRed, fontSize: fontSize)
        )
        return NSSize(width: ceil(bounds.width), height: ceil(bounds.height))
    }

    func savePNGToDesktop(closeAfterSave: Bool = false) {
        commitActiveText()
        guard let data = renderFinalImage().pngData() else { return }
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser
        let fileName = "SC \(Self.fileTimestamp()).png"
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
        formatter.dateFormat = "dd-MM-yy HH.mm.ss"
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

private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
    Swift.min(Swift.max(value, minimum), maximum)
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

extension EditorCanvasView: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === activeNumberField else { return false }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            commitActiveNumberEdit(apply: true)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            commitActiveNumberEdit(apply: false)
            return true
        }
        return false
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === activeNumberField else { return }
        commitActiveNumberEdit(apply: true)
    }
}

private extension Annotation {
    var isText: Bool {
        if case .text = kind { return true }
        return false
    }

    var isResizable: Bool {
        switch kind {
        case .rectangle, .pixelate, .text, .step:
            return true
        case .arrow:
            return false
        }
    }
}

private final class MultilineCommittingTextView: NSTextView {
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
