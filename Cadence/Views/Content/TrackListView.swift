import SwiftUI

struct TrackListView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackController.self) private var playbackController

    @State private var hoveredRow: UUID?

    private var tracks: [Track] {
        libraryStore.filteredTracks(query: uiState.searchQuery, from: libraryStore.allTracks())
    }

    var body: some View {
        LibraryContentShell {
            if tracks.isEmpty {
                EmptyLibraryStateView(message: "Нет треков")
            } else {
                ScrollView {
                    trackListHeader
                    ForEach(tracks) { track in
                        TrackRowView(
                            track: track,
                            isActive: playbackController.playingTrackID == track.id,
                            isPlaying: playbackController.isPlaying,
                            isHovered: hoveredRow == track.id,
                            onPlay: { playbackController.playTrack(track) }
                        )
                        .onHover { hoveredRow = $0 ? track.id : nil }
                    }
                    Color.clear.frame(height: 24)
                }
            }
        }
    }

    private var trackListHeader: some View {
        TrackListHeaderView()
    }
}

struct TrackListHeaderView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 40)
            Text("Название")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Альбом")
                .frame(width: 180, alignment: .leading)
            Image(systemName: "clock")
                .font(.system(size: 11))
                .frame(width: 60, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .semibold))
        .tracking(0.04 * 11)
        .textCase(.uppercase)
        .foregroundStyle(CadenceTheme.mutedText(for: colorScheme))
        .padding(.horizontal, 28)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08))
                .frame(height: 1)
        }
    }
}

struct TrackListRowView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(\.colorScheme) private var colorScheme

    let track: Track
    let isActive: Bool
    let isPlaying: Bool
    let isHovered: Bool
    var onPlay: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if isActive && isPlaying {
                    EqualizerBarsView(size: 13)
                } else if isHovered {
                    Button(action: onPlay) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(isActive ? CadenceTheme.accent(for: colorScheme) : CadenceTheme.primaryText(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("\(track.index)")
                        .font(.system(size: 13))
                        .monospacedDigit()
                        .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                }
            }
            .frame(width: 40)

            Text(track.title.isEmpty ? "—" : track.title)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? CadenceTheme.accent(for: colorScheme) : CadenceTheme.primaryText(for: colorScheme))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 12)

            Text(libraryStore.album(for: track.albumID)?.title ?? "—")
                .font(.system(size: 12))
                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                .lineLimit(1)
                .frame(width: 180, alignment: .leading)

            Text(CadenceTheme.formatTime(track.duration))
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 28)
        .frame(height: CadenceTheme.trackRowHeight)
        .background(isHovered ? CadenceTheme.rowHoverBackground(for: colorScheme) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onPlay)
    }
}
