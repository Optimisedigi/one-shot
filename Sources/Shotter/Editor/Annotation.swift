import AppKit

struct Annotation {
    static let defaultRectangleLineWidth: CGFloat = 5
    static let defaultArrowLineWidth: CGFloat = 3
    static let defaultTextFontSize: CGFloat = 27
    static let defaultPixelBlockScale: CGFloat = 12
    static let defaultStepRadius: CGFloat = 18
    static let minimumLineWidth: CGFloat = 1
    static let maximumLineWidth: CGFloat = 24
    static let minimumPixelBlockScale: CGFloat = 4
    static let maximumPixelBlockScale: CGFloat = 36
    static let minimumTextFontSize: CGFloat = 8
    static let maximumTextFontSize: CGFloat = 96
    static let minimumStepRadius: CGFloat = 10
    static let maximumStepRadius: CGFloat = 72

    enum Kind {
        case rectangle(NSRect)
        case arrow(start: NSPoint, end: NSPoint)
        case text(String, origin: NSPoint, fontSize: CGFloat)
        case pixelate(NSRect)
        case step(number: Int, center: NSPoint, radius: CGFloat)
    }

    var kind: Kind
    var color: NSColor = .systemRed
    /// Border/outline color. Currently used for the ring around Step badges,
    /// independent from the badge's fill `color`.
    var borderColor: NSColor = .white
    var lineWidth: CGFloat = Annotation.defaultArrowLineWidth

    var isStep: Bool {
        if case .step = kind { return true }
        return false
    }
}
