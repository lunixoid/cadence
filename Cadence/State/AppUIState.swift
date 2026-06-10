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
    var activeSidebarItem: SidebarItem = .tracks
    var contentRoute: ContentRoute = .tracksList
    var navigationStack: [ContentRoute] = []
    var forwardStack: [ContentRoute] = []
    var searchQuery = ""
    var hoveredTrackIndex: Int?

    var isSidebarOpen = true
    var isQueueOpen = false
    var isEQOpen = false
    var isPrefsOpen = false
    var isConnectOpen = false
    var appThemePreference: AppThemePreference = .system

    var jellyfinServers: [JellyfinServer] = []
    var activeJellyfinClient: JellyfinClient?

    private let serversKey = "cadence.jellyfinServers"
    private let navigationStateStore = NavigationStateStore()

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
        persistNavigationState()
    }

    func selectPlaylist(_ playlist: Playlist) {
        navigationStack.append(contentRoute)
        forwardStack.removeAll()
        contentRoute = .playlistDetail(playlist.id)
        persistNavigationState()
    }

    func openAlbum(_ album: Album) {
        navigationStack.append(contentRoute)
        forwardStack.removeAll()
        contentRoute = .albumDetail(album.id)
        activeSidebarItem = .albums
        persistNavigationState()
    }

    func openArtist(_ name: String) {
        navigationStack.append(contentRoute)
        forwardStack.removeAll()
        contentRoute = .artistDetail(name)
        activeSidebarItem = .artists
        persistNavigationState()
    }

    func navigateBack() {
        if let previous = navigationStack.popLast() {
            forwardStack.append(contentRoute)
            contentRoute = previous
            syncSidebarItem(for: previous)
        } else {
            contentRoute = route(for: activeSidebarItem)
        }
        persistNavigationState()
    }

    func navigateForward() {
        guard let next = forwardStack.popLast() else { return }
        navigationStack.append(contentRoute)
        contentRoute = next
        syncSidebarItem(for: next)
        persistNavigationState()
    }

    func restoreNavigationState(playlistStore: PlaylistStore) {
        guard let snapshot = navigationStateStore.load() else { return }

        contentRoute = normalizeRoute(snapshot.contentRoute, playlistStore: playlistStore)
        navigationStack = snapshot.navigationStack.filter {
            isRouteValid($0, playlistStore: playlistStore)
        }
        forwardStack = snapshot.forwardStack.filter {
            isRouteValid($0, playlistStore: playlistStore)
        }

        if let sidebar = contentRoute.sidebarItem {
            activeSidebarItem = sidebar
        } else {
            activeSidebarItem = snapshot.activeSidebarItem
        }
    }

    func canNavigateBack() -> Bool {
        !navigationStack.isEmpty
    }

    func canNavigateForward() -> Bool {
        !forwardStack.isEmpty
    }

    func toggleSidebar() {
        isSidebarOpen.toggle()
    }

    func toggleQueue() {
        guard activeSidebarItem != .nowPlaying else { return }
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

    func connectJellyfinServer(_ server: JellyfinServer, favoritesSync: JellyfinFavoritesSync) {
        var updated = server
        updated.isActive = true
        jellyfinServers.removeAll { $0.isActive }
        jellyfinServers.append(updated)
        saveServers()
        Task {
            await activateClient(for: updated, favoritesSync: favoritesSync)
        }
    }

    func removeJellyfinServer(_ id: UUID) {
        jellyfinServers.removeAll { $0.id == id }
        if activeJellyfinClient != nil && !jellyfinServers.contains(where: { $0.isActive }) {
            activeJellyfinClient = nil
        }
        JellyfinLibraryCache.remove(serverID: id)
        saveServers()
    }

    func restoreServers(favoritesSync: JellyfinFavoritesSync) async {
        guard let data = UserDefaults.standard.data(forKey: serversKey),
              let servers = try? JSONDecoder().decode([JellyfinServer].self, from: data) else { return }
        jellyfinServers = servers
        if let active = servers.first(where: { $0.isActive }) {
            await activateClient(for: active, favoritesSync: favoritesSync)
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

    private func activateClient(for server: JellyfinServer, favoritesSync: JellyfinFavoritesSync? = nil) async {
        guard let client = try? JellyfinClient(server: server) else { return }
        activeJellyfinClient = client

        if let cached = JellyfinLibraryCache.load(serverID: server.id) {
            libraryStore.loadFromJellyfin(cached)
            let coverURLs = cached.albums.compactMap(\.coverURL)
            Task(priority: .utility) {
                await ArtworkCache.shared.prefetch(coverURLs: coverURLs)
            }
        }

        let loader = JellyfinLibraryLoader(client: client, libraryStore: libraryStore, serverID: server.id)
        await loader.loadFullLibrary()
        if let favoritesSync {
            await favoritesSync.syncFromServer(client: client)
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

    private func persistNavigationState() {
        navigationStateStore.save(
            NavigationStateSnapshot(
                activeSidebarItem: activeSidebarItem,
                contentRoute: contentRoute,
                navigationStack: navigationStack,
                forwardStack: forwardStack
            )
        )
    }

    private func isRouteValid(_ route: ContentRoute, playlistStore: PlaylistStore) -> Bool {
        switch route {
        case .albumDetail(let id):
            return libraryStore.album(for: id) != nil
        case .artistDetail(let name):
            return libraryStore.artists.contains { $0.name == name }
        case .playlistDetail(let id):
            return playlistStore.playlist(for: id) != nil
        default:
            return true
        }
    }

    private func normalizeRoute(_ route: ContentRoute, playlistStore: PlaylistStore) -> ContentRoute {
        if isRouteValid(route, playlistStore: playlistStore) {
            return route
        }
        switch route {
        case .albumDetail:
            return .albumsGrid
        case .artistDetail:
            return .artistsGrid
        case .playlistDetail:
            return .tracksList
        default:
            return .tracksList
        }
    }
}
