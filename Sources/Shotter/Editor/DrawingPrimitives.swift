import AppKit

extension EditorCanvasView {
    func drawRectangle(_ rect: NSRect, color: NSColor, lineWidth: CGFloat) {
        color.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = lineWidth
        path.stroke()
    }

    func drawArrow(start: NSPoint, end: NSPoint, bend: CGFloat, color: NSColor, lineWidth: CGFloat) {
        ArrowShape.draw(start: start, end: end, bend: bend, color: color, lineWidth: lineWidth)
    }

    func drawText(_ text: String, at origin: NSPoint, color: NSColor, backgroundColor: NSColor, fontSize: CGFloat) {
        TextAnnotationStyle.draw(text, at: origin, color: color, backgroundColor: backgroundColor, fontSize: fontSize)
    }

    func drawPixelate(_ rect: NSRect, scale: CGFloat, from baseImage: NSImage) {
        if let image = PixelateRenderer.pixelatedImage(from: baseImage, rect: rect, scale: scale) {
            image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
        } else {
            NSColor.black.withAlphaComponent(0.85).setFill()
            rect.fill()
        }
    }

    func drawStep(number: Int, center: NSPoint, radius: CGFloat, color: NSColor, borderColor: NSColor = .white) {
        let circleRect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let circle = NSBezierPath(ovalIn: circleRect)
        color.setFill()
        circle.fill()
        borderColor.setStroke()
        circle.lineWidth = Annotation.stepRingWidth(for: radius)
        circle.stroke()

        let fontSize = max(10, radius * 1.05)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let text = String(number)
        let textSize = text.size(withAttributes: attributes)
        let textOrigin = NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2)
        text.draw(at: textOrigin, withAttributes: attributes)
    }

}
