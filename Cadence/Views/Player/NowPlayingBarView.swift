import SwiftUI

struct NowPlayingBarView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(PlaybackController.self) private var playbackController
    @Environment(FavoritesStore.self) private var favoritesStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var isProgressHovered = false
    @State private var isPlayHovered = false

    private var duration: TimeInterval {
        max(playbackController.duration, 1)
    }

    private var currentTrack: Track? {
        playbackController.currentTrack
    }

    private var currentAlbum: Album? {
        playbackController.album()
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .headerView)
                .overlay {
                    CadenceTheme.nowPlayingBackground(for: colorScheme)
                }

            HStack(spacing: 12) {
                leftSection
                centerSection
                rightSection
            }
            .padding(.horizontal, 16)
        }
        .frame(height: CadenceTheme.nowPlayingBarHeight)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CadenceTheme.borderColor(for: colorScheme))
                .frame(height: 0.5)
        }
    }

    private var leftSection: some View {
        HStack(spacing: 8) {
            Button(action: { uiState.selectSidebarItem(.nowPlaying) }) {
                HStack(spacing: 12) {
                    AlbumCoverView(
                        album: currentAlbum,
                        size: CadenceTheme.miniCoverSize,
                        cornerRadius: CadenceTheme.miniCoverRadius
                    )
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(currentTrack?.title ?? "—")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                            .lineLimit(1)

                        Text(currentTrack?.artist ?? "—")
                            .font(.system(size: 11))
                            .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                            .lineLimit(1)
                    }
                    .frame(minWidth: 0)
                }
            }
            .buttonStyle(.plain)

            if let track = currentTrack {
                PlayerButton(
                    size: 24,
                    isActive: favoritesStore.isFavorite(track: track)
                ) {
                    favoritesStore.toggle(track: track)
                } label: {
                    Image(systemName: favoritesStore.isFavorite(track: track) ? "heart.fill" : "heart")
                        .font(.system(size: 13))
                }
            }
        }
        .frame(width: 220, alignment: .leading)
    }

    private var centerSection: some View {
        VStack(spacing: 4) {
            HStack(spacing: 16) {
                PlayerButton(size: 26, isActive: playbackController.shuffleOn) {
                    playbackController.toggleShuffle()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 14))
                }

                PlayerButton(size: 26) {
                    playbackController.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                }

                Button(action: { playbackController.togglePlayPause() }) {
                    Image(systemName: playbackController.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(colorScheme == .dark ? Color(red: 0.118, green: 0.118, blue: 0.125) : .white)
                        .frame(width: CadenceTheme.playButtonSize, height: CadenceTheme.playButtonSize)
                        .background(CadenceTheme.primaryText(for: colorScheme))
                        .clipShape(Circle())
                        .scaleEffect(isPlayHovered ? 1.07 : 1)
                }
                .buttonStyle(.plain)
                .onHover { isPlayHovered = $0 }

                PlayerButton(size: 26) {
                    playbackController.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                }

                PlayerButton(
                    size: 26,
                    isActive: playbackController.repeatMode != .off
                ) {
                    playbackController.toggleRepeat()
                } label: {
                    Image(systemName: playbackController.repeatMode.iconName)
                        .font(.system(size: 14))
                }
            }

            HStack(spacing: 8) {
                Text(CadenceTheme.formatTime(playbackController.progress))
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                    .frame(minWidth: 32, alignment: .trailing)

                progressBar

                Text(CadenceTheme.formatTime(duration))
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                    .frame(minWidth: 32, alignment: .leading)
            }
        }
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(CadenceTheme.trackBackground(for: colorScheme))
                    .frame(height: isProgressHovered ? CadenceTheme.progressBarHoverHeight : CadenceTheme.progressBarHeight)

                Capsule()
                    .fill(CadenceTheme.accent(for: colorScheme))
                    .frame(
                        width: geometry.size.width * CGFloat(playbackController.progress / duration),
                        height: isProgressHovered ? CadenceTheme.progressBarHoverHeight : CadenceTheme.progressBarHeight
                    )
                    .overlay(alignment: .trailing) {
                        if isProgressHovered {
                            Circle()
                                .fill(CadenceTheme.accent(for: colorScheme))
                                .frame(width: CadenceTheme.progressThumbSize, height: CadenceTheme.progressThumbSize)
                                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                                .offset(x: CadenceTheme.progressThumbSize / 2)
                        }
                    }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .onHover { isProgressHovered = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = min(max(value.location.x / geometry.size.width, 0), 1)
                        playbackController.seek(to: duration * Double(ratio))
                    }
            )
            .animation(.easeOut(duration: 0.12), value: isProgressHovered)
        }
        .frame(height: CadenceTheme.progressBarHoverHeight)
    }

    private var rightSection: some View {
        HStack(spacing: 8) {
            PlayerButton(size: 24, action: {}) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 14))
            }
            .help("Очередь — скоро")
            .disabled(true)
            .opacity(0.4)

            PlayerButton(size: 24, action: {}) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14))
            }
            .help("Эквалайзер — скоро")
            .disabled(true)
            .opacity(0.4)

            HStack(spacing: 6) {
                Image(systemName: playbackController.volume == 0 ? "speaker.slash" : "speaker.wave.2")
                    .font(.system(size: 14))
                    .foregroundStyle(CadenceTheme.iconColor(for: colorScheme))

                volumeSlider
            }
        }
        .frame(width: 220, alignment: .trailing)
    }

    private var volumeSlider: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(CadenceTheme.trackBackground(for: colorScheme))
                    .frame(height: CadenceTheme.volumeSliderHeight)

                Capsule()
                    .fill(CadenceTheme.volumeFill(for: colorScheme))
                    .frame(
                        width: geometry.size.width * CGFloat(playbackController.volume / 100),
                        height: CadenceTheme.volumeSliderHeight
                    )
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = min(max(value.location.x / geometry.size.width, 0), 1)
                        playbackController.volume = Double(ratio * 100)
                    }
            )
        }
        .frame(width: CadenceTheme.volumeSliderWidth, height: CadenceTheme.volumeSliderHeight)
    }
}
