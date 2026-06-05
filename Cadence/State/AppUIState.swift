import SwiftUI

@Observable
final class AppUIState {
    var activeSidebarItem: SidebarItem = .albums
    var contentRoute: ContentRoute = .albumsGrid
    var navigationStack: [ContentRoute] = []
    var searchQuery = ""
    var hoveredTrackIndex: Int?

    let libraryStore: LibraryStore

    init(libraryStore: LibraryStore) {
        self.libraryStore = libraryStore
    }

    var downloadedCount: Int {
        libraryStore.allTracks().count
    }

    var albums: [Album] {
        libraryStore.filteredAlbums(query: searchQuery)
    }

    func album(for id: UUID) -> Album? {
        libraryStore.album(for: id)
    }

    func tracks(for album: Album) -> [Track] {
        libraryStore.filteredTracks(query: searchQuery, from: libraryStore.tracks(for: album))
    }

    func selectSidebarItem(_ item: SidebarItem) {
        activeSidebarItem = item
        navigationStack.removeAll()
        contentRoute = route(for: item)
    }

    func selectPlaylist(_ playlist: Playlist) {
        navigationStack.append(contentRoute)
        contentRoute = .playlistDetail(playlist.id)
    }

    func openAlbum(_ album: Album) {
        navigationStack.append(contentRoute)
        contentRoute = .albumDetail(album.id)
        activeSidebarItem = .albums
    }

    func openArtist(_ name: String) {
        navigationStack.append(contentRoute)
        contentRoute = .artistDetail(name)
        activeSidebarItem = .artists
    }

    func openGenre(_ name: String) {
        navigationStack.append(contentRoute)
        contentRoute = .genreDetail(name)
        activeSidebarItem = .genres
    }

    func navigateBack() {
        if let previous = navigationStack.popLast() {
            contentRoute = previous
            if let sidebar = previous.sidebarItem {
                activeSidebarItem = sidebar
            }
        } else {
            contentRoute = route(for: activeSidebarItem)
        }
    }

    func canNavigateBack() -> Bool {
        !navigationStack.isEmpty
    }

    func toolbarTitle(playlistStore: PlaylistStore) -> String {
        switch contentRoute {
        case .nowPlaying:
            return SidebarItem.nowPlaying.label
        case .tracksList:
            return SidebarItem.tracks.label
        case .albumsGrid, .albumDetail:
            return SidebarItem.albums.label
        case .artistsGrid, .artistDetail:
            return SidebarItem.artists.label
        case .genresGrid, .genreDetail:
            return SidebarItem.genres.label
        case .favorites:
            return SidebarItem.favorites.label
        case .recent:
            return SidebarItem.recent.label
        case .downloaded:
            return SidebarItem.downloaded.label
        case .playlistDetail(let id):
            return playlistStore.playlist(for: id)?.name ?? "Плейлист"
        }
    }

    private func route(for item: SidebarItem) -> ContentRoute {
        switch item {
        case .nowPlaying: return .nowPlaying
        case .tracks: return .tracksList
        case .albums: return .albumsGrid
        case .artists: return .artistsGrid
        case .genres: return .genresGrid
        case .favorites: return .favorites
        case .recent: return .recent
        case .downloaded: return .downloaded
        }
    }
}
