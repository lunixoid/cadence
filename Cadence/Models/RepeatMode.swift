import Foundation

enum RepeatMode: String, Codable, CaseIterable {
    case off
    case queue
    case one

    mutating func cycle() {
        switch self {
        case .off: self = .queue
        case .queue: self = .one
        case .one: self = .off
        }
    }

    var iconName: String {
        switch self {
        case .off, .queue: return "repeat"
        case .one: return "repeat.1"
        }
    }
}
