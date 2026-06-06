import AppKit
import SwiftUI

struct WindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragRegionView {
        WindowDragRegionView()
    }

    func updateNSView(_ nsView: WindowDragRegionView, context: Context) {}
}

final class WindowDragRegionView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}

struct MainWindowView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(PlaybackController.self) private var playbackController
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var resolvedColorScheme: ColorScheme {
        switch uiState.appThemePreference {
        case .system:
            return colorScheme
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var body: some View {
        ZStack {
            mainLayout

            overlayLayer
        }
        .preferredColorScheme(uiState.appThemePreference == .system ? nil : resolvedColorScheme)
        .background(CadenceTheme.windowBackground(for: resolvedColorScheme))
        .background(WindowConfigurator())
        .background {
            PlaybackKeyboardMonitor(controller: playbackController)
        }
        .onAppear {
            PlaybackKeyboardMonitorService.shared.install(controller: playbackController)
        }
    }

    private var mainLayout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebarPanel

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        contentColumn
                        QueuePanelView(isOpen: uiState.isQueueOpen)
                    }

                    NowPlayingBarView()
                }
            }
        }
    }

    private var sidebarPanel: some View {
        ZStack(alignment: .trailing) {
            if uiState.isSidebarOpen {
                SidebarView()
                    .frame(width: CadenceTheme.sidebarWidth)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(width: uiState.isSidebarOpen ? CadenceTheme.sidebarWidth : 0)
        .clipped()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: uiState.isSidebarOpen)
    }

    private var overlayLayer: some View {
        ZStack {
            if uiState.isPrefsOpen || uiState.isConnectOpen {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if uiState.isConnectOpen {
                            uiState.closeConnect()
                        } else {
                            uiState.closePreferences()
                        }
                    }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    EQWindowView(
                        isOpen: uiState.isEQOpen,
                        onClose: { uiState.isEQOpen = false }
                    )
                    .padding(.trailing, CadenceTheme.eqWindowRightOffset)
                    .padding(.bottom, CadenceTheme.eqWindowBottomOffset)
                }
            }

            if uiState.isPrefsOpen {
                PreferencesWindowView(
                    isOpen: uiState.isPrefsOpen,
                    onClose: { uiState.closePreferences() },
                    onAddServer: { uiState.openConnectFromPreferences() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            if uiState.isConnectOpen {
                ConnectWindowView(
                    isOpen: uiState.isConnectOpen,
                    onClose: { uiState.closeConnect() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
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
        .background(CadenceTheme.contentBackground(for: resolvedColorScheme))
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
        window.isMovableByWindowBackground = false
        window.backgroundColor = .clear
    }
}
