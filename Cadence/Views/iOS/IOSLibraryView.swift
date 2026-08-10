import SwiftUI

enum IOSLibrarySegment: String, CaseIterable, Identifiable {
    case tracks
    case albums
    case artists

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tracks: return "Все треки"
        case .albums: return "Альбомы"
        case .artists: return "Артисты"
        }
    }
}

struct IOSLibraryView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackController.self) private var playbackController
    @Environment(\.colorScheme) private var colorScheme

    @State private var segment: IOSLibrarySegment = .albums

    private var tracks: [Track] {
        libraryStore.filteredTracks(query: uiState.searchQuery, from: libraryStore.allTracks())
    }

    private var albums: [Album] {
        uiState.albums
    }

    private var artists: [Artist] {
        let query = uiState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = libraryStore.artists
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        @Bindable var ui = uiState

        Group {
            switch segment {
            case .tracks:
                tracksList
            case .albums:
                albumsGrid
            case .artists:
                artistsList
            }
        }
        .background(CadenceTheme.contentBackground(for: colorScheme))
        .navigationTitle("Библиотека")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $ui.searchQuery, prompt: "Поиск")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    uiState.openPreferences()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Настройки")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Раздел", selection: $segment) {
                ForEach(IOSLibrarySegment.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(CadenceTheme.contentBackground(for: colorScheme))
        }
    }

    private var tracksList: some View {
        List {
            ForEach(tracks) { track in
                Button {
                    playbackController.playTrack(track, in: tracks, source: .library)
                } label: {
                    IOSTrackRow(
                        title: track.title,
                        subtitle: track.artist,
                        trailing: CadenceTheme.formatTime(track.duration),
                        isActive: playbackController.playingTrackID == track.id
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .overlay {
            if tracks.isEmpty {
                ContentUnavailableView("Нет треков", systemImage: "music.note")
            }
        }
    }

    private var albumsGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 16)],
                spacing: 20
            ) {
                ForEach(albums) { album in
                    NavigationLink(value: album.id) {
                        VStack(alignment: .leading, spacing: 8) {
                            AlbumCoverView(album: album, size: 150, cornerRadius: 8)
                            Text(album.title.isEmpty ? "—" : album.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                                .lineLimit(2)
                            Text(album.artist.isEmpty ? "—" : album.artist)
                                .font(.system(size: 12))
                                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .overlay {
            if albums.isEmpty {
                ContentUnavailableView("Нет альбомов", systemImage: "square.stack")
            }
        }
    }

    private var artistsList: some View {
        List {
            ForEach(artists) { artist in
                let artistAlbums = libraryStore.albums(forArtist: artist.name)
                if let first = artistAlbums.first {
                    NavigationLink(value: first.id) {
                        IOSTrackRow(
                            title: artist.name,
                            subtitle: "\(artistAlbums.count) альб.",
                            trailing: nil,
                            isActive: false
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if artists.isEmpty {
                ContentUnavailableView("Нет артистов", systemImage: "person.2")
            }
        }
    }
}

struct IOSTrackRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String
    let trailing: String?
    var isActive: Bool = false
    var favorite: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title.isEmpty ? "—" : title)
                        .font(.system(size: 15, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(
                            isActive
                                ? CadenceTheme.accent(for: colorScheme)
                                : CadenceTheme.primaryText(for: colorScheme)
                        )
                        .lineLimit(1)
                    if favorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 1, green: 0.216, blue: 0.373))
                    }
                }
                Text(subtitle.isEmpty ? "—" : subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
            }
        }
        .contentShape(Rectangle())
    }
}
