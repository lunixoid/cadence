import SwiftUI

@main
struct CadenceApp: App {
    @State private var libraryStore = LibraryStore()
    @State private var playlistStore = PlaylistStore()
    @State private var favoritesStore = FavoritesStore()
    @State private var recentStore = RecentStore()
    @State private var playbackController: PlaybackController
    @State private var uiState: AppUIState

    init() {
        let library = LibraryStore()
        let recent = RecentStore()
        _libraryStore = State(initialValue: library)
        _recentStore = State(initialValue: recent)
        _playbackController = State(initialValue: PlaybackController(libraryStore: library, recentStore: recent))
        _uiState = State(initialValue: AppUIState(libraryStore: library))
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(uiState)
                .environment(libraryStore)
                .environment(playlistStore)
                .environment(favoritesStore)
                .environment(recentStore)
                .environment(playbackController)
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
