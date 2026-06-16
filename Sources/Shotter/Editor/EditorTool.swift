import Foundation

enum EditorTool: String, CaseIterable {
    case rectangle = "Rectangle"
    case arrow = "Arrow"
    case text = "Text"

    var iconTitle: String {
        switch self {
        case .rectangle: return "▭"
        case .arrow: return "↗"
        case .text: return "T"
        }
    }
}
