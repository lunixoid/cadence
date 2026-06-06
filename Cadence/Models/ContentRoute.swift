import Foundation

enum ContentRoute: Equatable, Hashable {
    case nowPlaying
    case tracksList
    case albumsGrid
    case albumDetail(UUID)
    case artistsGrid
    case artistDetail(String)
    case favorites
    case recent
    case downloaded
    case playlistDetail(UUID)

    var sidebarItem: SidebarItem? {
        switch self {
        case .nowPlaying: return .nowPlaying
        case .tracksList: return .tracks
        case .albumsGrid, .albumDetail: return .albums
        case .artistsGrid, .artistDetail: return .artists
        case .favorites: return .favorites
        case .recent: return .recent
        case .downloaded: return .downloaded
        case .playlistDetail: return nil
        }
    }

    var supportsNavigationArrows: Bool {
        switch self {
        case .nowPlaying, .tracksList, .favorites, .recent, .downloaded:
            return false
        default:
            return true
        }
    }
}
