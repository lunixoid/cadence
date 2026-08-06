import SwiftUI

struct FavoritesView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(FavoritesStore.self) private var favoritesStore
    @Environment(PlaybackController.self) private var playbackController

    private var tracks: [Track] {
        let source = libraryStore.allTracks().filter { favoritesStore.isFavorite(track: $0) }
        return libraryStore.filteredTracks(query: uiState.searchQuery, from: source)
    }

    var body: some View {
        LibraryContentShell {
            if tracks.isEmpty {
                EmptyLibraryStateView(message: "Нет избранного")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        Section(header: TrackListHeaderView()) {
                            ForEach(tracks) { track in
                                TrackRowView(
                                    track: track,
                                    isActive: playbackController.playingTrackID == track.id,
                                    disambiguationLabel: libraryStore.disambiguationLabel(for: track)
                                )
                            }
                            Color.clear.frame(height: 24)
                        }
                    }
                }
            }
        }
    }
}

struct RecentView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(RecentStore.self) private var recentStore
    @Environment(PlaybackController.self) private var playbackController

    private var tracks: [Track] {
        libraryStore.filteredTracks(query: uiState.searchQuery, from: recentStore.tracks(from: libraryStore))
    }

    var body: some View {
        LibraryContentShell {
            if tracks.isEmpty {
                EmptyLibraryStateView(message: "Нет недавних треков")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        Section(header: TrackListHeaderView()) {
                            ForEach(tracks) { track in
                                TrackRowView(
                                    track: track,
                                    isActive: playbackController.playingTrackID == track.id,
                                    disambiguationLabel: libraryStore.disambiguationLabel(for: track)
                                )
                            }
                            Color.clear.frame(height: 24)
                        }
                    }
                }
            }
        }
    }
}

struct DownloadedView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(OfflineStore.self) private var offlineStore
    @Environment(PlaybackController.self) private var playbackController

    private var tracks: [Track] {
        var seen = Set<UUID>()
        var combined: [Track] = []
        for track in libraryStore.localTracks() + offlineStore.offlineTracks(from: libraryStore) {
            if seen.insert(track.id).inserted {
                combined.append(track)
            }
        }
        return libraryStore.filteredTracks(query: uiState.searchQuery, from: combined)
    }

    var body: some View {
        LibraryContentShell {
            if tracks.isEmpty {
                EmptyLibraryStateView(message: "Нет скачанных треков")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        Section(header: TrackListHeaderView()) {
                            ForEach(tracks) { track in
                                TrackRowView(
                                    track: track,
                                    isActive: playbackController.playingTrackID == track.id,
                                    disambiguationLabel: libraryStore.disambiguationLabel(for: track)
                                )
                            }
                            Color.clear.frame(height: 24)
                        }
                    }
                }
            }
        }
    }
}
