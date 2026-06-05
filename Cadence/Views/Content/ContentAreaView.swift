import SwiftUI

struct ContentAreaView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(PlaylistStore.self) private var playlistStore

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbarView(
                title: uiState.toolbarTitle(playlistStore: playlistStore)
            )
            AlbumGridView()
        }
    }
}
