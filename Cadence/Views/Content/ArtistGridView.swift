import SwiftUI

struct ArtistGridView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(\.colorScheme) private var colorScheme

    private var artists: [Artist] {
        libraryStore.filteredArtists(query: uiState.searchQuery)
    }

    var body: some View {
        LibraryContentShell {
            if artists.isEmpty {
                EmptyLibraryStateView(message: "Нет артистов")
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)],
                        alignment: .leading,
                        spacing: 12
                    ) {
                        ForEach(artists) { artist in
                            Button {
                                uiState.openArtist(artist.name)
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(CadenceTheme.accent(for: colorScheme).opacity(0.2))
                                        .frame(width: 48, height: 48)
                                        .overlay {
                                            Image(systemName: "person.fill")
                                                .foregroundStyle(CadenceTheme.accent(for: colorScheme))
                                        }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(artist.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                                            .lineLimit(1)
                                        Text("\(artist.albumIDs.count) альбомов")
                                            .font(.system(size: 11))
                                            .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(CadenceTheme.rowHoverBackground(for: colorScheme).opacity(0.5))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}

struct ArtistDetailView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackController.self) private var playbackController

    let artistName: String

    private var albums: [Album] {
        libraryStore.filteredAlbums(query: uiState.searchQuery)
            .filter { $0.artist.caseInsensitiveCompare(artistName) == .orderedSame }
    }

    private let columns = [
        GridItem(.adaptive(minimum: CadenceTheme.albumCardWidth, maximum: CadenceTheme.albumCardWidth), spacing: 16),
    ]

    var body: some View {
        LibraryContentShell(title: artistName) {
            if albums.isEmpty {
                EmptyLibraryStateView(message: "Нет альбомов")
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(albums) { album in
                            AlbumCardView(album: album) {
                                uiState.openAlbum(album)
                            } onPlay: {
                                playbackController.playAlbum(album, shuffled: false)
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}
