import Foundation

enum PreferencesTab: String, CaseIterable, Identifiable {
    case servers
    case playback
    case cache
    case appearance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .servers: return "Серверы"
        case .playback: return "Воспроизведение"
        case .cache: return "Кеш и оффлайн"
        case .appearance: return "Внешний вид"
        }
    }

    var iconName: String {
        switch self {
        case .servers: return "server.rack"
        case .playback: return "play.circle"
        case .cache: return "externaldrive"
        case .appearance: return "circle.lefthalf.filled"
        }
    }
}

struct ServerEntry: Identifiable, Equatable {
    let id: UUID
    var name: String
    var url: String
    var status: ServerStatus
    var isActive: Bool
    var user: String
    var authMethod: String

    enum ServerStatus {
        case online
        case offline

        var label: String {
            switch self {
            case .online: return "Онлайн"
            case .offline: return "Офлайн"
            }
        }
    }
}
