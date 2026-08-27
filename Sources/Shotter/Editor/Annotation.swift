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
        /// `bend` is how far the arc bows sideways; 0 is a straight arrow.
        case arrow(start: NSPoint, end: NSPoint, bend: CGFloat)
        case text(String, origin: NSPoint, fontSize: CGFloat)
        case pixelate(NSRect)
        case step(number: Int, center: NSPoint, radius: CGFloat)
    }

    var kind: Kind
    var color: NSColor = .systemRed
    /// Secondary color, independent from `color`: the ring around a Step
    /// badge, and the card behind a Text annotation.
    var borderColor: NSColor = .white
    var lineWidth: CGFloat = Annotation.defaultArrowLineWidth

    var isStep: Bool {
        if case .step = kind { return true }
        return false
    }

    /// Kinds that draw a second color the user can change.
    var hasBorderColor: Bool {
        switch kind {
        case .step, .text: return true
        case .rectangle, .arrow, .pixelate: return false
        }
    }

    /// Thickness of the ring drawn around a Step badge, shared by drawing
    /// code and hit-testing so the pressable number area always matches
    /// what's visually inside the ring.
    static func stepRingWidth(for radius: CGFloat) -> CGFloat {
        max(2, radius * 0.14)
    }
}
