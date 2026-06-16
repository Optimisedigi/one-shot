import AppKit

enum ImageRenderer {
    static func render(baseImage: NSImage, annotations: [Annotation]) -> NSImage {
        let image = NSImage(size: baseImage.size)
        image.lockFocus()
        baseImage.draw(in: NSRect(origin: .zero, size: baseImage.size), from: NSRect(origin: .zero, size: baseImage.size), operation: .sourceOver, fraction: 1)
        for annotation in annotations {
            switch annotation.kind {
            case .rectangle(let rect):
                drawRectangle(rect, color: annotation.color, lineWidth: annotation.lineWidth)
            case .arrow(let start, let end):
                drawArrow(start: start, end: end, color: annotation.color, lineWidth: annotation.lineWidth)
            case .text(let text, let origin):
                drawText(text, at: origin, color: annotation.color)
            }
        }
        image.unlockFocus()
        return image
    }

    private static func drawRectangle(_ rect: NSRect, color: NSColor, lineWidth: CGFloat) {
        color.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = lineWidth
        path.stroke()
    }

    private static func drawArrow(start: NSPoint, end: NSPoint, color: NSColor, lineWidth: CGFloat) {
        color.setStroke()
        color.setFill()
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.stroke()

        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength: CGFloat = 18
        let headAngle: CGFloat = .pi / 7
        let p1 = NSPoint(x: end.x - headLength * cos(angle - headAngle), y: end.y - headLength * sin(angle - headAngle))
        let p2 = NSPoint(x: end.x - headLength * cos(angle + headAngle), y: end.y - headLength * sin(angle + headAngle))
        let head = NSBezierPath()
        head.move(to: end)
        head.line(to: p1)
        head.line(to: p2)
        head.close()
        head.fill()
    }

    private static func drawText(_ text: String, at origin: NSPoint, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: color,
            .strokeColor: NSColor.white,
            .strokeWidth: -2
        ]
        text.draw(at: origin, withAttributes: attributes)
    }

}
