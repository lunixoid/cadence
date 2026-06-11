import SwiftUI

struct AlbumGridView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(PlaybackController.self) private var playbackController
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.adaptive(minimum: CadenceTheme.albumCardWidth, maximum: CadenceTheme.albumCardWidth), spacing: 16),
    ]

    var body: some View {
        Group {
            if uiState.albums.isEmpty {
                EmptyLibraryStateView(message: "Нет альбомов")
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(uiState.albums) { album in
                            AlbumCardView(album: album) {
                                uiState.openAlbum(album)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
