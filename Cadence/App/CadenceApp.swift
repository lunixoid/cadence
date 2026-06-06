import SwiftUI

@main
struct CadenceApp: App {
    @State private var libraryStore = LibraryStore()
    @State private var playlistStore = PlaylistStore()
    @State private var favoritesStore = FavoritesStore()
    @State private var jellyfinFavoritesSync: JellyfinFavoritesSync
    @State private var recentStore = RecentStore()
    @State private var playbackController: PlaybackController
    @State private var uiState: AppUIState

    init() {
        let library = LibraryStore()
        let recent = RecentStore()
        let favorites = FavoritesStore()
        _libraryStore = State(initialValue: library)
        _favoritesStore = State(initialValue: favorites)
        _jellyfinFavoritesSync = State(initialValue: JellyfinFavoritesSync(
            favoritesStore: favorites,
            libraryStore: library
        ))
        _recentStore = State(initialValue: recent)
        let playback = PlaybackController(libraryStore: library, recentStore: recent)
        _playbackController = State(initialValue: playback)
        _uiState = State(initialValue: AppUIState(libraryStore: library))
        PlaybackKeyboardMonitorService.shared.install(controller: playback)
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(uiState)
                .environment(libraryStore)
                .environment(playlistStore)
                .environment(favoritesStore)
                .environment(jellyfinFavoritesSync)
                .environment(recentStore)
                .environment(playbackController)
                .task {
                    await libraryStore.restoreSavedFolders()
                    await uiState.restoreServers(favoritesSync: jellyfinFavoritesSync)
                    playbackController.restoreSavedState()
                }
        }
        .defaultSize(
            width: CadenceTheme.defaultWindowWidth,
            height: CadenceTheme.defaultWindowHeight
        )
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("File") {
                Button("Open Music Folder…") {
                    openMusicFolder()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandMenu("Playback") {
                Button("Play / Pause") {
                    playbackController.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Next Track") {
                    playbackController.next()
                }

                Button("Previous Track") {
                    playbackController.previous()
                }
            }
            CommandMenu("View") {
                Button("Toggle Sidebar") {
                    uiState.toggleSidebar()
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Toggle Queue") {
                    uiState.toggleQueue()
                }
                .keyboardShortcut("l", modifiers: .command)

                Button("Show Equalizer") {
                    uiState.isEQOpen = true
                }
                .keyboardShortcut("e", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Preferences…") {
                    uiState.openPreferences()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    @MainActor
    private func openMusicFolder() {
        guard let url = FolderPicker.pickMusicFolder() else { return }
        Task {
            await libraryStore.loadFolder(url)
            uiState.selectSidebarItem(.albums)
        }
    }
}
