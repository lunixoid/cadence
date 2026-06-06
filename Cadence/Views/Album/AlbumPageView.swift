import AppKit
import SwiftUI

struct AlbumPageView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(PlaybackController.self) private var playbackController
    @Environment(\.colorScheme) private var colorScheme

    let album: Album

    private var tracks: [Track] {
        uiState.tracks(for: album)
    }

    private var dominantColor: Color {
        album.accentColors.count > 1 ? album.accentColors[1] : CadenceTheme.placeholderGradientColors[1]
    }

    var body: some View {
        VStack(spacing: 0) {
            albumToolbar

            ScrollView {
                VStack(spacing: 0) {
                    heroSection

                    trackListHeader

                    if tracks.isEmpty {
                        Text("Нет треков")
                            .font(.system(size: 14))
                            .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 16)
                    } else {
                        ForEach(tracks) { track in
                            TrackRowView(
                                track: track,
                                isActive: playbackController.playingTrackID == track.id,
                                isPlaying: playbackController.isPlaying,
                                onPlay: { playbackController.playTrack(track) }
                            )
                        }
                    }

                    Color.clear.frame(height: 24)
                }
            }
        }
    }

    private var albumToolbar: some View {
        HStack(spacing: 12) {
            Button(action: { uiState.navigateBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CadenceTheme.iconColor(for: colorScheme))
                    .frame(width: CadenceTheme.navButtonSize, height: CadenceTheme.navButtonSize)
                    .background(
                        RoundedRectangle(cornerRadius: CadenceTheme.navButtonRadius, style: .continuous)
                            .fill(CadenceTheme.navBackground(for: colorScheme))
                    )
            }
            .buttonStyle(.plain)

            Button("Альбомы") {
                uiState.navigateBack()
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: CadenceTheme.toolbarHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                .frame(height: 0.5)
        }
    }

    private var heroSection: some View {
        HStack(alignment: .bottom, spacing: 24) {
            AlbumCoverView(
                album: album,
                size: CadenceTheme.albumHeroCoverSize,
                cornerRadius: CadenceTheme.albumHeroCoverRadius
            )
            .shadow(color: dominantColor.opacity(0.33), radius: 16, y: 8)
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 0) {
                Text(album.title.isEmpty ? "—" : album.title)
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.025 * 26)
                    .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                    .lineLimit(2)
                    .padding(.bottom, 4)

                Text(album.artist.isEmpty ? "—" : album.artist)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(CadenceTheme.accent(for: colorScheme))
                    .padding(.bottom, 8)

                HStack(spacing: 6) {
                    metaText(album.year.map(String.init) ?? "—")
                    metaSeparator
                    metaText(album.genre ?? "—")
                    metaSeparator
                    metaText(tracks.isEmpty ? "—" : "\(tracks.count) треков")
                    metaSeparator
                    metaText(tracks.isEmpty ? "—" : "\(totalMinutes) мин")
                }
                .padding(.bottom, 16)

                HStack(spacing: 8) {
                    Button(action: { playbackController.playAlbum(album, shuffled: false) }) {
                        Label("Воспроизвести", systemImage: "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 7)
                            .background(CadenceTheme.accent(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(tracks.isEmpty)

                    Button(action: { playbackController.playAlbum(album, shuffled: true) }) {
                        Label("Перемешать", systemImage: "shuffle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(CadenceTheme.secondaryButtonBackground(for: colorScheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(CadenceTheme.borderColor(for: colorScheme), lineWidth: 0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(tracks.isEmpty)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [dominantColor.opacity(colorScheme == .dark ? 0.13 : 0.09), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var trackListHeader: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 40)
            Text("Название")
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private var totalMinutes: Int {
        Int(tracks.reduce(0) { $0 + $1.duration } / 60)
    }

    private func metaText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
    }

    private var metaSeparator: some View {
        Text("·")
            .font(.system(size: 12))
            .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme).opacity(0.4))
    }
}
