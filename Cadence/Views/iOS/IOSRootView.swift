import SwiftUI

enum IOSTab: Hashable {
    case library
    case recent
    case favorites
    case downloaded
}

struct IOSRootView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(PlaybackController.self) private var playbackController

    @State private var selectedTab: IOSTab = .library
    @State private var showNowPlaying = false

    var body: some View {
        @Bindable var ui = uiState

        TabView(selection: $selectedTab) {
            Tab("Библиотека", systemImage: "rectangle.stack.fill", value: .library) {
                NavigationStack {
                    IOSLibraryView()
                        .navigationDestination(for: UUID.self) { albumID in
                            if let album = uiState.album(for: albumID) {
                                IOSAlbumView(album: album)
                            }
                        }
                }
            }

            Tab("Недавнее", systemImage: "clock", value: .recent) {
                NavigationStack {
                    IOSRecentView()
                        .navigationDestination(for: UUID.self) { albumID in
                            if let album = uiState.album(for: albumID) {
                                IOSAlbumView(album: album)
                            }
                        }
                }
            }

            Tab("Избранное", systemImage: "heart.fill", value: .favorites) {
                NavigationStack {
                    IOSFavoritesView()
                        .navigationDestination(for: UUID.self) { albumID in
                            if let album = uiState.album(for: albumID) {
                                IOSAlbumView(album: album)
                            }
                        }
                }
            }

            Tab("Скачанное", systemImage: "arrow.down.circle.fill", value: .downloaded) {
                NavigationStack {
                    IOSDownloadedView()
                        .navigationDestination(for: UUID.self) { albumID in
                            if let album = uiState.album(for: albumID) {
                                IOSAlbumView(album: album)
                            }
                        }
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            if playbackController.currentTrack != nil {
                IOSMiniPlayerView(
                    onOpenNowPlaying: { showNowPlaying = true },
                    onOpenQueue: { ui.isQueueOpen = true }
                )
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            IOSNowPlayingView(onOpenQueue: {
                showNowPlaying = false
                ui.isQueueOpen = true
            })
        }
        .sheet(isPresented: $ui.isQueueOpen) {
            IOSQueueView()
        }
        .sheet(isPresented: $ui.isPrefsOpen) {
            NavigationStack {
                IOSSettingsView()
            }
        }
        .tint(CadenceTheme.accent(for: .light))
    }
}
