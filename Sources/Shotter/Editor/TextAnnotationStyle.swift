import AppKit

/// One definition of how a text annotation looks: bold text on a rounded
/// card (white with red text by default, plus a drop shadow so the card
/// edge reads on light screenshots). Shared by the canvas, the inline
/// editor and the exported image so what you type is what you get.
enum TextAnnotationStyle {
    static let defaultBackgroundColor = NSColor.white
    static let defaultColor = NSColor.systemRed

    static func font(ofSize fontSize: CGFloat) -> NSFont {
        .systemFont(ofSize: fontSize, weight: .bold)
    }

    static func attributes(color: NSColor, fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [.font: font(ofSize: fontSize), .foregroundColor: color]
    }

    /// Space between the text and the edge of the card.
    static func padding(for fontSize: CGFloat) -> NSSize {
        NSSize(width: max(8, fontSize * 0.45), height: max(5, fontSize * 0.3))
    }

    static func cornerRadius(for fontSize: CGFloat) -> CGFloat {
        max(6, fontSize * 0.32)
    }

    static func textSize(_ text: String, fontSize: CGFloat) -> NSSize {
        let bounds = text.boundingRect(
            with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes(color: defaultColor, fontSize: fontSize)
        )
        return NSSize(width: ceil(bounds.width), height: ceil(bounds.height))
    }

    /// The card around text drawn at `origin`.
    static func boxRect(for text: String, at origin: NSPoint, fontSize: CGFloat) -> NSRect {
        let pad = padding(for: fontSize)
        return NSRect(origin: origin, size: textSize(text, fontSize: fontSize))
            .insetBy(dx: -pad.width, dy: -pad.height)
    }

    static func cardShadow(for fontSize: CGFloat) -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowBlurRadius = max(4, fontSize * 0.18)
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        return shadow
    }

    static func draw(_ text: String, at origin: NSPoint, color: NSColor, backgroundColor: NSColor, fontSize: CGFloat) {
        let radius = cornerRadius(for: fontSize)
        let path = NSBezierPath(roundedRect: boxRect(for: text, at: origin, fontSize: fontSize), xRadius: radius, yRadius: radius)
        NSGraphicsContext.saveGraphicsState()
        cardShadow(for: fontSize).set()
        backgroundColor.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
        // Fill again so the card itself stays fully opaque; the first fill only casts the shadow.
        backgroundColor.setFill()
        path.fill()
        text.draw(
            with: NSRect(origin: origin, size: textSize(text, fontSize: fontSize)),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes(color: color, fontSize: fontSize)
        )
    }
}
