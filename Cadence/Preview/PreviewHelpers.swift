#if DEBUG
import SwiftUI

enum PreviewData {
    static let albumID = UUID()
    static let fileURL = URL(fileURLWithPath: "/tmp/preview.mp3")

    static let album = Album(
        id: albumID,
        title: "Preview Album",
        artist: "Preview Artist",
        year: 2024,
        accentColors: [
            Color(red: 0.36, green: 0.22, blue: 0.57),
            Color(red: 0.56, green: 0.27, blue: 0.68),
            Color(red: 0.76, green: 0.61, blue: 0.83),
        ]
    )

    static let tracks: [Track] = [
        Track(index: 1, title: "Track One", artist: "Preview Artist", albumID: albumID, duration: 214, fileURL: fileURL),
        Track(index: 2, title: "Track Two", artist: "Preview Artist", albumID: albumID, duration: 187, fileURL: fileURL),
        Track(index: 3, title: "Track Three", artist: "Preview Artist", albumID: albumID, duration: 245, fileURL: fileURL),
    ]

    @MainActor
    static func makeEnvironment() -> (AppUIState, LibraryStore, PlaylistStore, FavoritesStore, OfflineStore, JellyfinFavoritesSync, RecentStore, PlaybackController) {
        let library = LibraryStore()
        let recent = RecentStore()
        let favorites = FavoritesStore()
        let offline = OfflineStore()
        let favoritesSync = JellyfinFavoritesSync(
            favoritesStore: favorites,
            libraryStore: library,
            offlineStore: offline
        )
        let playback = PlaybackController(
            libraryStore: library,
            recentStore: recent,
            offlineStore: offline
        )
        let uiState = AppUIState(libraryStore: library)

        return (uiState, library, PlaylistStore(), favorites, offline, favoritesSync, recent, playback)
    }

    @MainActor
    static func stateWithAlbumPage() -> (AppUIState, LibraryStore, PlaylistStore, FavoritesStore, OfflineStore, JellyfinFavoritesSync, RecentStore, PlaybackController) {
        let env = makeEnvironment()
        env.1.loadPreview(result: LibraryScanResult(
            albums: [album],
            tracks: tracks,
            artists: [Artist(name: album.artist, albumIDs: [album.id])]
        ))
        env.0.contentRoute = .albumDetail(album.id)
        env.7.loadPreviewState(
            tracks: tracks,
            currentIndex: 1,
            isPlaying: true,
            progress: 67,
            duration: 234
        )
        return env
    }
}

#Preview("Main Window") {
    let env = PreviewData.makeEnvironment()
    MainWindowView()
        .environment(env.0)
        .environment(env.1)
        .environment(env.2)
        .environment(env.3)
        .environment(env.4)
        .environment(env.5)
        .environment(env.6)
        .environment(env.7)
        .frame(width: 1100, height: 700)
}

#Preview("Album Page") {
    let env = PreviewData.stateWithAlbumPage()
    AlbumPageView(album: PreviewData.album)
        .environment(env.0)
        .environment(env.1)
        .environment(env.2)
        .environment(env.3)
        .environment(env.4)
        .environment(env.5)
        .environment(env.6)
        .environment(env.7)
        .frame(width: 880, height: 600)
}

#Preview("Now Playing Bar") {
    let env = PreviewData.stateWithAlbumPage()
    NowPlayingBarView()
        .environment(env.0)
        .environment(env.1)
        .environment(env.2)
        .environment(env.3)
        .environment(env.4)
        .environment(env.5)
        .environment(env.6)
        .environment(env.7)
        .frame(width: 1100)
}
#endif
