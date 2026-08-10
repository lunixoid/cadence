import SwiftUI

struct IOSRecentView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(RecentStore.self) private var recentStore
    @Environment(\.colorScheme) private var colorScheme

    private var albums: [Album] {
        var seen = Set<UUID>()
        var result: [Album] = []
        for track in recentStore.tracks(from: libraryStore) {
            guard seen.insert(track.albumID).inserted,
                  let album = libraryStore.album(for: track.albumID) else { continue }
            result.append(album)
        }
        return result
    }

    var body: some View {
        List {
            ForEach(albums) { album in
                NavigationLink(value: album.id) {
                    HStack(spacing: 12) {
                        AlbumCoverView(album: album, size: 56, cornerRadius: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(album.title.isEmpty ? "—" : album.title)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                            Text(album.artist.isEmpty ? "—" : album.artist)
                                .font(.system(size: 12))
                                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Недавнее")
        .overlay {
            if albums.isEmpty {
                ContentUnavailableView("Нет недавних альбомов", systemImage: "clock")
            }
        }
    }
}

struct IOSFavoritesView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(FavoritesStore.self) private var favoritesStore
    @Environment(PlaybackController.self) private var playbackController
    @Environment(\.colorScheme) private var colorScheme

    private var tracks: [Track] {
        libraryStore.allTracks().filter { favoritesStore.isFavorite(track: $0) }
    }

    var body: some View {
        List {
            ForEach(tracks) { track in
                Button {
                    playbackController.playTrack(track, in: tracks, source: .library)
                } label: {
                    IOSTrackRow(
                        title: track.title,
                        subtitle: track.artist,
                        trailing: CadenceTheme.formatTime(track.duration),
                        isActive: playbackController.playingTrackID == track.id,
                        favorite: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Избранное")
        .overlay {
            if tracks.isEmpty {
                ContentUnavailableView("Нет избранного", systemImage: "heart")
            }
        }
    }
}

struct IOSDownloadedView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(OfflineStore.self) private var offlineStore
    @Environment(\.colorScheme) private var colorScheme

    private var albums: [Album] {
        var seen = Set<UUID>()
        var result: [Album] = []
        let tracks = libraryStore.localTracks() + offlineStore.offlineTracks(from: libraryStore)
        for track in tracks {
            guard seen.insert(track.albumID).inserted,
                  let album = libraryStore.album(for: track.albumID) else { continue }
            result.append(album)
        }
        return result.sorted {
            ($0.title.lowercased(), $0.artist.lowercased()) < ($1.title.lowercased(), $1.artist.lowercased())
        }
    }

    var body: some View {
        List {
            ForEach(albums) { album in
                NavigationLink(value: album.id) {
                    HStack(spacing: 12) {
                        AlbumCoverView(album: album, size: 56, cornerRadius: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(album.title.isEmpty ? "—" : album.title)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                            Text(album.artist.isEmpty ? "—" : album.artist)
                                .font(.system(size: 12))
                                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Скачанное")
        .overlay {
            if albums.isEmpty {
                ContentUnavailableView("Нет скачанных альбомов", systemImage: "arrow.down.circle")
            }
        }
    }
}
