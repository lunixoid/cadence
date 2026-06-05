import SwiftUI

struct MainWindowView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                SidebarView()
                contentColumn
            }
            NowPlayingBarView()
        }
        .background(CadenceTheme.windowBackground(for: colorScheme))
        .background(WindowConfigurator())
    }

    @ViewBuilder
    private var contentColumn: some View {
        Group {
            switch uiState.contentRoute {
            case .albumsGrid:
                ContentAreaView()
            case .albumDetail(let id):
                if let album = uiState.album(for: id) {
                    AlbumPageView(album: album)
                } else {
                    ContentAreaView()
                }
            case .nowPlaying:
                NowPlayingDetailView()
            case .tracksList:
                TrackListView()
            case .artistsGrid:
                ArtistGridView()
            case .artistDetail(let name):
                ArtistDetailView(artistName: name)
            case .genresGrid:
                GenreGridView()
            case .genreDetail(let name):
                GenreDetailView(genreName: name)
            case .favorites:
                FavoritesView()
            case .recent:
                RecentView()
            case .downloaded:
                DownloadedView()
            case .playlistDetail(let id):
                PlaylistDetailView(playlistID: id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CadenceTheme.contentBackground(for: colorScheme))
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configureWindow(for: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(for: nsView)
        }
    }

    private func configureWindow(for view: NSView) {
        guard let window = view.window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
    }
}
