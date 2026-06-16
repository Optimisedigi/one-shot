import AppKit

enum Geometry {
    static func cgCaptureRect(fromAppKitRect rect: NSRect, in screen: NSScreen) -> CGRect {
        CGRect(
            x: rect.minX,
            y: screen.frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func aspectFitRect(imageSize: NSSize, in bounds: NSRect) -> NSRect {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    static func normalizedRect(from start: NSPoint, to end: NSPoint) -> NSRect {
        NSRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y))
    }
}
