import AppKit

enum ImageRenderer {
    /// Flattens the annotations onto the capture at the capture's own pixel
    /// size. (`NSImage.lockFocus` would use the main screen's scale instead,
    /// upscaling — and bloating — captures taken on a lower-density display.)
    static func render(baseImage: NSImage, annotations: [Annotation]) -> CGImage? {
        let size = baseImage.size
        guard size.width > 0, size.height > 0 else { return nil }
        let source = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        let pixelWidth = source?.width ?? Int(size.width.rounded(.up))
        let pixelHeight = source?.height ?? Int(size.height.rounded(.up))
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: RGBPixels.colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.scaleBy(x: CGFloat(pixelWidth) / size.width, y: CGFloat(pixelHeight) / size.height)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.restoreGraphicsState() }

        baseImage.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1)
        for annotation in annotations {
            switch annotation.kind {
            case .rectangle(let rect):
                drawRectangle(rect, color: annotation.color, lineWidth: annotation.lineWidth)
            case .arrow(let start, let end, let bend):
                ArrowShape.draw(start: start, end: end, bend: bend, color: annotation.color, lineWidth: annotation.lineWidth)
            case .text(let text, let origin, let fontSize):
                drawText(text, at: origin, color: annotation.color, backgroundColor: annotation.borderColor, fontSize: fontSize)
            case .pixelate(let rect):
                drawPixelate(rect, scale: annotation.lineWidth, from: baseImage)
            case .step(let number, let center, let radius):
                drawStep(number: number, center: center, radius: radius, color: annotation.color, borderColor: annotation.borderColor)
            }
        }
        return context.makeImage()
    }

    private static func drawRectangle(_ rect: NSRect, color: NSColor, lineWidth: CGFloat) {
        color.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = lineWidth
        path.stroke()
    }

    private static func drawText(_ text: String, at origin: NSPoint, color: NSColor, backgroundColor: NSColor, fontSize: CGFloat) {
        TextAnnotationStyle.draw(text, at: origin, color: color, backgroundColor: backgroundColor, fontSize: fontSize)
    }

    private static func drawPixelate(_ rect: NSRect, scale: CGFloat, from baseImage: NSImage) {
        if let image = PixelateRenderer.pixelatedImage(from: baseImage, rect: rect, scale: scale) {
            image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
        } else {
            NSColor.black.withAlphaComponent(0.85).setFill()
            rect.fill()
        }
    }

    private static func drawStep(number: Int, center: NSPoint, radius: CGFloat, color: NSColor, borderColor: NSColor) {
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
