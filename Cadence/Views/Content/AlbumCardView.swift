import SwiftUI

struct AlbumCardView: View {
    @Environment(PlaybackController.self) private var playbackController
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(OfflineStore.self) private var offlineStore
    @Environment(AppUIState.self) private var uiState
    @Environment(\.colorScheme) private var colorScheme

    let album: Album
    var onTap: () -> Void

    @State private var isHovered = false

    private var albumTracks: [Track] {
        libraryStore.tracks(for: album)
    }

    private var canManageOffline: Bool {
        uiState.activeJellyfinClient != nil
            && albumTracks.contains { !$0.fileURL.isFileURL }
    }

    private var allOfflineReady: Bool {
        let remote = albumTracks.filter { !$0.fileURL.isFileURL }
        guard !remote.isEmpty else { return false }
        return remote.allSatisfy { offlineStore.isReady($0.id) }
    }

    private var anyDownloading: Bool {
        albumTracks.contains {
            switch offlineStore.state(for: $0.id) {
            case .queued, .downloading: return true
            default: return false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                AlbumCoverView(
                    album: album,
                    size: CadenceTheme.albumCardWidth - 12,
                    cornerRadius: CadenceTheme.albumCardRadius
                )

                Circle()
                    .fill(Color.black.opacity(0.55))
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(width: CadenceTheme.playOverlaySize, height: CadenceTheme.playOverlaySize)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }
                    .padding(8)
                    .opacity(isHovered ? 1 : 0)
                    .scaleEffect(isHovered ? 1 : 0.92)
                    .allowsHitTesting(isHovered)
                    .contentShape(Circle())
                    .onTapGesture(perform: handlePlay)
            }

            if !album.title.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    Text(album.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                        .lineLimit(1)

                    if !album.artist.isEmpty {
                        Text(album.artist)
                            .font(.system(size: 11))
                            .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                            .lineLimit(1)
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 2)
            }
        }
        .id(album.id)
        .frame(width: CadenceTheme.albumCardWidth)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: CadenceTheme.albumCardRadius, style: .continuous)
                .fill(
                    isHovered
                        ? CadenceTheme.rowHoverBackground(for: colorScheme)
                        : Color.clear
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .contextMenu {
            Button("Воспроизвести") {
                handlePlay()
            }
            if canManageOffline {
                Divider()
                albumOfflineMenuItems
            }
        }
    }

    private func handlePlay() {
        playbackController.playAlbum(album, shuffled: false)
    }

    @ViewBuilder
    private var albumOfflineMenuItems: some View {
        if anyDownloading {
            Button {} label: {
                Label("Загрузка альбома…", systemImage: "arrow.down.circle")
            }
            .disabled(true)
            Button {
                for track in albumTracks where !track.fileURL.isFileURL {
                    offlineStore.cancelDownload(trackID: track.id)
                }
            } label: {
                Label("Отменить загрузку", systemImage: "xmark.circle")
            }
        } else if allOfflineReady {
            Button {
                for track in albumTracks where !track.fileURL.isFileURL {
                    offlineStore.remove(trackID: track.id)
                }
            } label: {
                Label("Удалить загрузку альбома", systemImage: "arrow.down.circle.fill")
            }
        } else {
            Button {
                guard let client = uiState.activeJellyfinClient else { return }
                offlineStore.downloadAll(tracks: albumTracks, client: client, origin: .manual)
            } label: {
                Label("Загрузить альбом оффлайн", systemImage: "arrow.down.circle")
            }
        }
    }
}
