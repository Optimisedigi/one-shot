import AppKit

struct Annotation {
    enum Kind {
        case rectangle(NSRect)
        case arrow(start: NSPoint, end: NSPoint)
        case text(String, origin: NSPoint)
    }

    var kind: Kind
    var color: NSColor = .systemRed
    var lineWidth: CGFloat = 4
}
