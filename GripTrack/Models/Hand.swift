import Foundation

enum Hand: String, Codable, CaseIterable {
    case left
    case right

    var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        }
    }

    var abbreviation: String {
        switch self {
        case .left: return "L"
        case .right: return "R"
        }
    }
}

