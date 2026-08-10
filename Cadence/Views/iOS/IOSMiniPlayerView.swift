import SwiftUI

struct IOSMiniPlayerView: View {
    @Environment(PlaybackController.self) private var playbackController
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    let onOpenNowPlaying: () -> Void
    let onOpenQueue: () -> Void

    private var album: Album? {
        playbackController.album()
    }

    var body: some View {
        let compact = placement == .inline

        HStack(spacing: compact ? 8 : 12) {
            Button(action: onOpenNowPlaying) {
                HStack(spacing: compact ? 8 : 12) {
                    AlbumCoverView(
                        album: album,
                        size: compact ? 36 : 48,
                        cornerRadius: 6
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(playbackController.currentTrack?.title ?? "—")
                            .font(.system(size: compact ? 13 : 14, weight: .semibold))
                            .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                            .lineLimit(1)
                        if !compact {
                            Text(playbackController.currentTrack?.artist ?? "—")
                                .font(.system(size: 12))
                                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            Button {
                playbackController.togglePlayPause()
            } label: {
                Image(systemName: playbackController.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: compact ? 16 : 18, weight: .semibold))
                    .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playbackController.isPlaying ? "Пауза" : "Играть")

            Button(action: onOpenQueue) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Список воспроизведения")
        }
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 6 : 10)
        .contentShape(Rectangle())
    }
}
