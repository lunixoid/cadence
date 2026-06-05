import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case nowPlaying
    case tracks
    case albums
    case artists
    case genres
    case favorites
    case recent
    case downloaded

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nowPlaying: return "Сейчас играет"
        case .tracks: return "Все треки"
        case .albums: return "Альбомы"
        case .artists: return "Артисты"
        case .genres: return "Жанры"
        case .favorites: return "Избранное"
        case .recent: return "Недавнее"
        case .downloaded: return "Скачанное"
        }
    }

    var icon: String {
        switch self {
        case .nowPlaying: return "waveform"
        case .tracks: return "music.note"
        case .albums: return "opticaldisc"
        case .artists: return "person"
        case .genres: return "guitars"
        case .favorites: return "heart"
        case .recent: return "clock"
        case .downloaded: return "arrow.down.circle"
        }
    }

    var usesAccentWhenSelected: Bool {
        self != .favorites
    }

    var selectedIconColor: Color? {
        self == .favorites ? Color(red: 1, green: 0.22, blue: 0.37) : nil
    }

    static let libraryItems: [SidebarItem] = [.tracks, .albums, .artists, .genres]
    static let extraItems: [SidebarItem] = [.favorites, .recent, .downloaded]
}
