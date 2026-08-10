import SwiftUI

@main
struct CadenceiOSApp: App {
    @State private var libraryStore = LibraryStore()
    @State private var playlistStore = PlaylistStore()
    @State private var favoritesStore = FavoritesStore()
    @State private var offlineStore = OfflineStore()
    @State private var jellyfinFavoritesSync: JellyfinFavoritesSync
    @State private var recentStore = RecentStore()
    @State private var playbackController: PlaybackController
    @State private var uiState: AppUIState
    @State private var hasRestoredState = false

    init() {
        let library = LibraryStore()
        let recent = RecentStore()
        let favorites = FavoritesStore()
        let offline = OfflineStore()
        _libraryStore = State(initialValue: library)
        _favoritesStore = State(initialValue: favorites)
        _offlineStore = State(initialValue: offline)
        _jellyfinFavoritesSync = State(initialValue: JellyfinFavoritesSync(
            favoritesStore: favorites,
            libraryStore: library,
            offlineStore: offline
        ))
        _recentStore = State(initialValue: recent)
        let playback = PlaybackController(
            libraryStore: library,
            recentStore: recent,
            offlineStore: offline
        )
        _playbackController = State(initialValue: playback)
        let ui = AppUIState(libraryStore: library)
        _uiState = State(initialValue: ui)
    }

    var body: some Scene {
        WindowGroup {
            IOSRootView()
                .environment(uiState)
                .environment(libraryStore)
                .environment(playlistStore)
                .environment(favoritesStore)
                .environment(offlineStore)
                .environment(jellyfinFavoritesSync)
                .environment(recentStore)
                .environment(playbackController)
                .preferredColorScheme(preferredScheme)
                .task {
                    guard !hasRestoredState else { return }
                    hasRestoredState = true
                    offlineStore.pruneMissingFiles()
                    await uiState.restoreServers(favoritesSync: jellyfinFavoritesSync)
                    playbackController.restoreSavedState()
                    uiState.restoreNavigationState(playlistStore: playlistStore)
                }
        }
    }

    private var preferredScheme: ColorScheme? {
        switch uiState.appThemePreference {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
