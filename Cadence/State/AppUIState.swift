import SwiftUI

enum AppThemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Системная"
        case .light: return "Светлая"
        case .dark: return "Тёмная"
        }
    }
}

@Observable
final class AppUIState {
    var activeSidebarItem: SidebarItem = .albums
    var contentRoute: ContentRoute = .albumsGrid
    var navigationStack: [ContentRoute] = []
    var forwardStack: [ContentRoute] = []
    var searchQuery = ""
    var hoveredTrackIndex: Int?

    var isQueueOpen = false
    var isEQOpen = false
    var isPrefsOpen = false
    var isConnectOpen = false
    var appThemePreference: AppThemePreference = .system
    var configuredServers: [ServerEntry] = []

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
        forwardStack.removeAll()
        contentRoute = route(for: item)
    }

    func selectPlaylist(_ playlist: Playlist) {
        navigationStack.append(contentRoute)
        forwardStack.removeAll()
        contentRoute = .playlistDetail(playlist.id)
    }

    func openAlbum(_ album: Album) {
        navigationStack.append(contentRoute)
        forwardStack.removeAll()
        contentRoute = .albumDetail(album.id)
        activeSidebarItem = .albums
    }

    func openArtist(_ name: String) {
        navigationStack.append(contentRoute)
        forwardStack.removeAll()
        contentRoute = .artistDetail(name)
        activeSidebarItem = .artists
    }

    func openGenre(_ name: String) {
        navigationStack.append(contentRoute)
        forwardStack.removeAll()
        contentRoute = .genreDetail(name)
        activeSidebarItem = .genres
    }

    func navigateBack() {
        if let previous = navigationStack.popLast() {
            forwardStack.append(contentRoute)
            contentRoute = previous
            syncSidebarItem(for: previous)
        } else {
            contentRoute = route(for: activeSidebarItem)
        }
    }

    func navigateForward() {
        guard let next = forwardStack.popLast() else { return }
        navigationStack.append(contentRoute)
        contentRoute = next
        syncSidebarItem(for: next)
    }

    func canNavigateBack() -> Bool {
        !navigationStack.isEmpty
    }

    func canNavigateForward() -> Bool {
        !forwardStack.isEmpty
    }

    func toggleQueue() {
        isQueueOpen.toggle()
    }

    func toggleEQ() {
        isEQOpen.toggle()
    }

    func openPreferences() {
        isPrefsOpen = true
    }

    func closePreferences() {
        isPrefsOpen = false
    }

    func openConnectFromPreferences() {
        isPrefsOpen = false
        isConnectOpen = true
    }

    func closeConnect() {
        isConnectOpen = false
    }

    func registerConnectedServer(
        url: String,
        username: String,
        authMethod: String
    ) {
        let entry = ServerEntry(
            id: UUID(),
            name: url,
            url: url,
            status: .online,
            isActive: configuredServers.isEmpty,
            user: username,
            authMethod: authMethod
        )
        configuredServers.append(entry)
    }

    private func syncSidebarItem(for route: ContentRoute) {
        if let sidebar = route.sidebarItem {
            activeSidebarItem = sidebar
        }
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
