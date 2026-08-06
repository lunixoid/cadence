import AppKit
import SwiftUI

struct TrackRowView: View {
    @Environment(PlaybackController.self) private var playbackController
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(FavoritesStore.self) private var favoritesStore
    @Environment(OfflineStore.self) private var offlineStore
    @Environment(JellyfinFavoritesSync.self) private var jellyfinFavoritesSync
    @Environment(AppUIState.self) private var uiState
    @Environment(\.colorScheme) private var colorScheme

    let track: Track
    let isActive: Bool
    var disambiguationLabel: String? = nil
    var playContextTracks: [Track]? = nil
    var playSource: AutoplaySource = .none

    @State private var isHovered = false

    private var rowIsPlaying: Bool {
        isActive && playbackController.isPlaying
    }

    private var canManageOffline: Bool {
        !track.fileURL.isFileURL && uiState.activeJellyfinClient != nil
    }

    private var offlineState: OfflineState {
        offlineStore.state(for: track.id)
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                if rowIsPlaying {
                    EqualizerBarsView(size: 13)
                        .allowsHitTesting(false)
                }

                Group {
                    if isHovered {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(isActive ? CadenceTheme.accent(for: colorScheme) : CadenceTheme.primaryText(for: colorScheme))
                    } else if isActive {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(CadenceTheme.accent(for: colorScheme))
                    } else {
                        Text("\(track.index)")
                            .font(.system(size: 13))
                            .monospacedDigit()
                            .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                    }
                }
                .frame(width: 40)
                .contentShape(Rectangle())
                .opacity(rowIsPlaying ? 0 : 1)
                .allowsHitTesting(!rowIsPlaying)
                .onTapGesture(perform: handlePlay)
            }
            .frame(width: 40)

            HStack(spacing: 0) {
                if let label = disambiguationLabel {
                    Text("\(label)/")
                        .foregroundStyle(CadenceTheme.mutedText(for: colorScheme))
                }
                Text(track.title.isEmpty ? "—" : track.title)
                    .foregroundStyle(isActive ? CadenceTheme.accent(for: colorScheme) : CadenceTheme.primaryText(for: colorScheme))
            }
            .font(.system(size: 13, weight: isActive ? .semibold : .regular))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 12)

            Text(CadenceTheme.formatTime(track.duration))
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                .frame(width: 60, alignment: .trailing)
        }
        .id(track.id)
        .padding(.horizontal, 28)
        .frame(height: CadenceTheme.trackRowHeight)
        .background(isHovered ? CadenceTheme.rowHoverBackground(for: colorScheme) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2, perform: handlePlay)
        .contextMenu {
            trackContextMenu
        }
    }

    private func handlePlay() {
        if let playContextTracks {
            playbackController.playTrack(track, in: playContextTracks, source: playSource)
        } else {
            playbackController.playTrack(track)
        }
    }

    @ViewBuilder
    private var trackContextMenu: some View {
        Button("Воспроизвести", action: handlePlay)
        Button("Воспроизвести далее") {
            playbackController.playNext(track)
        }
        Button("Добавить в очередь") {
            playbackController.addToQueue(track)
        }
        Divider()
        Menu("Добавить в плейлист") {
            if playlistStore.playlists.isEmpty {
                Button("Создайте плейлист в сайдбаре") {}
                    .disabled(true)
            } else {
                ForEach(playlistStore.playlists) { playlist in
                    Button(playlist.name) {
                        playlistStore.addTrack(track, to: playlist.id)
                    }
                }
            }
        }
        Button(favoritesStore.isFavorite(track: track) ? "Убрать из избранного" : "В избранное") {
            jellyfinFavoritesSync.toggle(track: track, client: uiState.activeJellyfinClient)
        }
        if canManageOffline {
            Divider()
            offlineMenuItems
        }
        Divider()
        Button("Показать в Finder") {
            if let offlineURL = offlineStore.localURL(for: track.id) {
                NSWorkspace.shared.activateFileViewerSelecting([offlineURL])
            } else if track.fileURL.isFileURL {
                NSWorkspace.shared.activateFileViewerSelecting([track.fileURL])
            }
        }
        .disabled(!track.fileURL.isFileURL && offlineStore.localURL(for: track.id) == nil)
    }

    @ViewBuilder
    private var offlineMenuItems: some View {
        switch offlineState {
        case .none:
            Button {
                guard let client = uiState.activeJellyfinClient else { return }
                offlineStore.download(track: track, client: client, origin: .manual)
            } label: {
                Label("Загрузить оффлайн", systemImage: "arrow.down.circle")
            }
        case .queued:
            Button {} label: {
                Label("Загрузка… 0%", systemImage: "arrow.down.circle")
            }
            .disabled(true)
            Button {
                offlineStore.cancelDownload(trackID: track.id)
            } label: {
                Label("Отменить загрузку", systemImage: "xmark.circle")
            }
        case .downloading(let progress):
            Button {} label: {
                Label("Загрузка… \(Int(progress * 100))%", systemImage: "arrow.down.circle")
            }
            .disabled(true)
            Button {
                offlineStore.cancelDownload(trackID: track.id)
            } label: {
                Label("Отменить загрузку", systemImage: "xmark.circle")
            }
        case .ready:
            Button {
                offlineStore.remove(trackID: track.id)
            } label: {
                Label("Удалить загрузку", systemImage: "arrow.down.circle.fill")
            }
        case .failed:
            Button {
                guard let client = uiState.activeJellyfinClient else { return }
                offlineStore.download(track: track, client: client, origin: .manual)
            } label: {
                Label("Повторить загрузку", systemImage: "arrow.clockwise")
            }
            .foregroundStyle(Color(red: 1, green: 0.231, blue: 0.188))
        }
    }
}
