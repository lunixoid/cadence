import SwiftUI

struct GenreGridView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(\.colorScheme) private var colorScheme

    private var genres: [Genre] {
        libraryStore.filteredGenres(query: uiState.searchQuery)
    }

    var body: some View {
        LibraryContentShell {
            if genres.isEmpty {
                EmptyLibraryStateView(message: "Нет жанров")
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 12)],
                        alignment: .leading,
                        spacing: 12
                    ) {
                        ForEach(genres) { genre in
                            Button {
                                uiState.openGenre(genre.name)
                            } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(CadenceTheme.accent(for: colorScheme).opacity(0.2))
                                        .frame(width: 48, height: 48)
                                        .overlay {
                                            Image(systemName: "guitars")
                                                .foregroundStyle(CadenceTheme.accent(for: colorScheme))
                                        }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(genre.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                                            .lineLimit(1)
                                        Text("\(genre.albumIDs.count) альбомов")
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

struct GenreDetailView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackController.self) private var playbackController

    let genreName: String

    private var albums: [Album] {
        libraryStore.filteredAlbums(query: uiState.searchQuery)
            .filter { ($0.genre ?? "").caseInsensitiveCompare(genreName) == .orderedSame }
    }

    private let columns = [
        GridItem(.adaptive(minimum: CadenceTheme.albumCardWidth, maximum: CadenceTheme.albumCardWidth), spacing: 16),
    ]

    var body: some View {
        LibraryContentShell(title: genreName) {
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
