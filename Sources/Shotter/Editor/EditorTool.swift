import Foundation

enum EditorTool: String, CaseIterable {
    case rectangle = "Rectangle"
    case arrow = "Arrow"
    case text = "Text"
    case pixelate = "Pixelate"
    case step = "Step"

    /// SF Symbol used for the toolbar button.
    var symbolName: String {
        switch self {
        case .rectangle: return "rectangle"
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        case .pixelate: return "mosaic"
        case .step: return "number.circle.fill"
        }
    }

    /// Text fallback used only if the SF Symbol above can't be resolved.
    var iconTitle: String {
        switch self {
        case .rectangle: return "▭"
        case .arrow: return "↗"
        case .text: return "T"
        case .pixelate: return "🔳"
        case .step: return "①"
        }
    }
}
