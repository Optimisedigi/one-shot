import Foundation

enum EditorTool: String, CaseIterable {
    case rectangle = "Rectangle"
    case arrow = "Arrow"
    case text = "Text"
    case pixelate = "Pixelate"
    case step = "Step"

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
