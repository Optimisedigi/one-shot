import AppKit

extension EditorCanvasView {
    func drawRectangle(_ rect: NSRect, color: NSColor, lineWidth: CGFloat) {
        color.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = lineWidth
        path.stroke()
    }

    func drawArrow(start: NSPoint, end: NSPoint, color: NSColor, lineWidth: CGFloat) {
        color.setStroke()
        color.setFill()
        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength: CGFloat = 18
        let headAngle: CGFloat = .pi / 7
        let arrowLength = hypot(end.x - start.x, end.y - start.y)
        let shaftInset = min(headLength * 0.72, max(0, arrowLength - lineWidth))
        let shaftEnd = NSPoint(x: end.x - shaftInset * cos(angle), y: end.y - shaftInset * sin(angle))

        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: shaftEnd)
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.stroke()

        let p1 = NSPoint(x: end.x - headLength * cos(angle - headAngle), y: end.y - headLength * sin(angle - headAngle))
        let p2 = NSPoint(x: end.x - headLength * cos(angle + headAngle), y: end.y - headLength * sin(angle + headAngle))
        let head = NSBezierPath()
        head.move(to: end)
        head.line(to: p1)
        head.line(to: p2)
        head.close()
        head.fill()
    }

    func drawText(_ text: String, at origin: NSPoint, color: NSColor, fontSize: CGFloat) {
        let size = Self.textSize(text, fontSize: fontSize)
        text.draw(
            with: NSRect(origin: origin, size: size),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: Self.textAttributes(color: color, fontSize: fontSize)
        )
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
        circle.lineWidth = max(2, radius * 0.14)
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
