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
@MainActor
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

    var jellyfinServers: [JellyfinServer] = []
    var activeJellyfinClient: JellyfinClient?

    private let serversKey = "cadence.jellyfinServers"

    let libraryStore: LibraryStore

    init(libraryStore: LibraryStore) {
        self.libraryStore = libraryStore
    }

    var downloadedCount: Int {
        libraryStore.localTracks().count
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
        if item == .nowPlaying {
            isQueueOpen = false
        }
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

    func connectJellyfinServer(_ server: JellyfinServer) {
        var updated = server
        updated.isActive = true
        jellyfinServers.removeAll { $0.isActive }
        jellyfinServers.append(updated)
        saveServers()
        activateClient(for: updated)
    }

    func removeJellyfinServer(_ id: UUID) {
        jellyfinServers.removeAll { $0.id == id }
        if activeJellyfinClient != nil && !jellyfinServers.contains(where: { $0.isActive }) {
            activeJellyfinClient = nil
        }
        saveServers()
    }

    func restoreServers() {
        guard let data = UserDefaults.standard.data(forKey: serversKey),
              let servers = try? JSONDecoder().decode([JellyfinServer].self, from: data) else { return }
        jellyfinServers = servers
        if let active = servers.first(where: { $0.isActive }) {
            activateClient(for: active)
        }
    }

    var configuredServers: [ServerEntry] {
        jellyfinServers.map { server in
            ServerEntry(
                id: server.id,
                name: server.name,
                url: server.urlString,
                status: .online,
                isActive: server.isActive,
                user: server.username.isEmpty ? server.userID : server.username,
                authMethod: server.username == "API Key" ? "API Key" : "Пароль"
            )
        }
    }

    // MARK: - Private

    private func saveServers() {
        guard let data = try? JSONEncoder().encode(jellyfinServers) else { return }
        UserDefaults.standard.set(data, forKey: serversKey)
    }

    private func activateClient(for server: JellyfinServer) {
        guard let client = try? JellyfinClient(server: server) else { return }
        activeJellyfinClient = client
        Task {
            let loader = JellyfinLibraryLoader(client: client, libraryStore: libraryStore)
            await loader.loadFullLibrary()
        }
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
        case .favorites: return .favorites
        case .recent: return .recent
        case .downloaded: return .downloaded
        }
    }
}
