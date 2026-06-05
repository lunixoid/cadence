import SwiftUI

struct NowPlayingDetailView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(PlaybackController.self) private var playbackController
    @Environment(\.colorScheme) private var colorScheme

    private var track: Track? { playbackController.currentTrack }
    private var album: Album? { playbackController.album() }

    var body: some View {
        LibraryContentShell {
            if let track, let album {
                ScrollView {
                    VStack(spacing: 24) {
                        AlbumCoverView(
                            album: album,
                            size: CadenceTheme.albumHeroCoverSize,
                            cornerRadius: CadenceTheme.albumHeroCoverRadius
                        )
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                        VStack(spacing: 6) {
                            Text(track.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                                .multilineTextAlignment(.center)

                            Text(track.artist)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(CadenceTheme.accent(for: colorScheme))

                            Text(album.title)
                                .font(.system(size: 13))
                                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                        }

                        HStack(spacing: 12) {
                            Button("Перейти к альбому") {
                                uiState.openAlbum(album)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(CadenceTheme.secondaryButtonBackground(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            Button(action: { playbackController.togglePlayPause() }) {
                                Label(
                                    playbackController.isPlaying ? "Пауза" : "Воспроизвести",
                                    systemImage: playbackController.isPlaying ? "pause.fill" : "play.fill"
                                )
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 7)
                                .background(CadenceTheme.accent(for: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                EmptyLibraryStateView(message: "Сейчас ничего не играет")
            }
        }
    }
}
