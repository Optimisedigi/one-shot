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
            case .text(let text, let origin, let fontSize):
                drawText(text, at: origin, color: annotation.color, fontSize: fontSize)
            case .pixelate(let rect):
                drawPixelate(rect, scale: annotation.lineWidth, from: baseImage)
            case .step(let number, let center, let radius):
                drawStep(number: number, center: center, radius: radius, color: annotation.color)
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

    private static func drawText(_ text: String, at origin: NSPoint, color: NSColor, fontSize: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: color
        ]
        let bounds = text.boundingRect(
            with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        text.draw(
            with: NSRect(origin: origin, size: NSSize(width: ceil(bounds.width), height: ceil(bounds.height))),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
    }

    private static func drawPixelate(_ rect: NSRect, scale: CGFloat, from baseImage: NSImage) {
        if let image = PixelateRenderer.pixelatedImage(from: baseImage, rect: rect, scale: scale) {
            image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
        } else {
            NSColor.black.withAlphaComponent(0.85).setFill()
            rect.fill()
        }
    }

    private static func drawStep(number: Int, center: NSPoint, radius: CGFloat, color: NSColor) {
        let circleRect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let circle = NSBezierPath(ovalIn: circleRect)
        color.setFill()
        circle.fill()
        NSColor.white.setStroke()
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
