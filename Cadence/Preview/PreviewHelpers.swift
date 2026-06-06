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
    static func makeEnvironment() -> (AppUIState, LibraryStore, PlaylistStore, FavoritesStore, RecentStore, PlaybackController) {
        let library = LibraryStore()
        let recent = RecentStore()
        let playback = PlaybackController(libraryStore: library, recentStore: recent)
        let uiState = AppUIState(libraryStore: library)

        return (uiState, library, PlaylistStore(), FavoritesStore(), recent, playback)
    }

    @MainActor
    static func stateWithAlbumPage() -> (AppUIState, LibraryStore, PlaylistStore, FavoritesStore, RecentStore, PlaybackController) {
        let env = makeEnvironment()
        env.1.loadPreview(result: LibraryScanResult(
            albums: [album],
            tracks: tracks,
            artists: [Artist(name: album.artist, albumIDs: [album.id])]
        ))
        env.0.contentRoute = .albumDetail(album.id)
        env.5.loadPreviewState(
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
        .frame(width: 1100)
}
#endif
