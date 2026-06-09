import SwiftUI

struct NowPlayingBarView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(PlaybackController.self) private var playbackController
    @Environment(FavoritesStore.self) private var favoritesStore
    @Environment(JellyfinFavoritesSync.self) private var jellyfinFavoritesSync
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isProgressHovered = false
    @State private var isPlayHovered = false
    @State private var isVolumeHovered = false
    @State private var isStripHovered = false

    private var collapsed: Bool {
        uiState.activeSidebarItem == .nowPlaying
    }

    private var duration: TimeInterval {
        max(playbackController.duration, 1)
    }

    private var currentTrack: Track? {
        playbackController.currentTrack
    }

    private var currentAlbum: Album? {
        playbackController.album()
    }

    private var barHeight: CGFloat {
        collapsed ? CadenceTheme.nowPlayingCollapsedBarHeight : CadenceTheme.nowPlayingBarHeight
    }

    var body: some View {
        ZStack {
            thinStripLayer
            fullBarLayer
        }
        .frame(height: barHeight)
        .clipped()
        .animation(heightAnimation, value: collapsed)
    }

    // MARK: - Layers

    private var thinStripLayer: some View {
        thinStripContent
            .opacity(collapsed ? 1 : 0)
            .allowsHitTesting(collapsed)
            .animation(stripOpacityAnimation, value: collapsed)
    }

    private var fullBarLayer: some View {
        fullBarContent
            .opacity(collapsed ? 0 : 1)
            .allowsHitTesting(!collapsed)
            .animation(fullBarOpacityAnimation, value: collapsed)
    }

    private var thinStripContent: some View {
        ZStack {
            barBackground

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(CadenceTheme.trackBackground(for: colorScheme))
                        .frame(height: isStripHovered ? 4 : 2)

                    Capsule()
                        .fill(CadenceTheme.accent(for: colorScheme))
                        .frame(
                            width: geometry.size.width * progressRatio,
                            height: isStripHovered ? 4 : 2
                        )
                        .overlay(alignment: .trailing) {
                            if isStripHovered {
                                Circle()
                                    .fill(CadenceTheme.accent(for: colorScheme))
                                    .frame(width: 10, height: 10)
                                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                                    .offset(x: 5)
                            }
                        }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .onHover { isStripHovered = $0 }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            seekProgress(at: value.location.x, width: geometry.size.width)
                        }
                )
            }
        }
        .frame(height: CadenceTheme.nowPlayingCollapsedBarHeight)
    }

    private var fullBarContent: some View {
        ZStack {
            barBackground

            HStack(spacing: 12) {
                leftSection
                centerSection
                rightSection
            }
            .padding(.horizontal, 20)
        }
        .frame(height: CadenceTheme.nowPlayingBarHeight)
    }

    private var barBackground: some View {
        ZStack {
            VisualEffectBackground(material: .headerView)
                .overlay {
                    CadenceTheme.nowPlayingBackground(for: colorScheme)
                }

            VStack {
                Rectangle()
                    .fill(CadenceTheme.borderColor(for: colorScheme))
                    .frame(height: 0.5)
                Spacer()
            }
        }
    }

    // MARK: - Full Bar Sections

    private var leftSection: some View {
        let ui = uiState
        let favorites = favoritesStore
        let favoritesSync = jellyfinFavoritesSync

        return HStack(spacing: 12) {
            Button(action: {
                ui.selectSidebarItem(.nowPlaying)
            }) {
                HStack(spacing: 12) {
                    AlbumCoverView(
                        album: currentAlbum,
                        size: CadenceTheme.miniCoverSize,
                        cornerRadius: CadenceTheme.miniCoverRadius
                    )
                    .shadow(color: .black.opacity(0.22), radius: 7, y: 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentTrack?.title ?? "—")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                            .lineLimit(1)

                        Text(currentTrack?.artist ?? "—")
                            .font(.system(size: 12))
                            .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                            .lineLimit(1)
                    }
                    .frame(minWidth: 0)
                }
            }
            .buttonStyle(.plain)

            if let track = currentTrack {
                PlayerButton(
                    size: 36,
                    isActive: favorites.isFavorite(track: track)
                ) {
                    favoritesSync.toggle(track: track, client: ui.activeJellyfinClient)
                } label: {
                    Image(systemName: favorites.isFavorite(track: track) ? "heart.fill" : "heart")
                        .font(.system(size: 17))
                }
            }
        }
        .frame(width: 230, alignment: .leading)
    }

    private var centerSection: some View {
        let pc = playbackController

        return VStack(spacing: 8) {
            HStack(spacing: 4) {
                PlayerButton(
                    size: CadenceTheme.playerIconButtonSize,
                    isActive: pc.shuffleOn
                ) {
                    pc.toggleShuffle()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 20))
                }

                transportButton(icon: "backward.fill") {
                    pc.previous()
                }

                Button(action: {
                    pc.togglePlayPause()
                }) {
                    Image(systemName: pc.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(colorScheme == .dark ? Color(red: 0.11, green: 0.11, blue: 0.12) : .white)
                        .frame(width: CadenceTheme.playButtonSize, height: CadenceTheme.playButtonSize)
                        .background(CadenceTheme.primaryText(for: colorScheme))
                        .clipShape(Circle())
                        .scaleEffect(isPlayHovered ? 1.06 : 1)
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.16), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .onHover { isPlayHovered = $0 }
                .animation(.easeOut(duration: 0.1), value: isPlayHovered)

                transportButton(icon: "forward.fill") {
                    pc.next()
                }

                PlayerButton(
                    size: CadenceTheme.playerIconButtonSize,
                    isActive: pc.repeatMode != .off
                ) {
                    pc.toggleRepeat()
                } label: {
                    Image(systemName: pc.repeatMode.iconName)
                        .font(.system(size: 20))
                }
            }

            HStack(spacing: 8) {
                Text(CadenceTheme.formatTime(playbackController.progress))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                    .frame(minWidth: 36, alignment: .trailing)

                progressBar

                Text(CadenceTheme.formatTime(duration))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                    .frame(minWidth: 36, alignment: .leading)
            }
            .frame(maxWidth: 440)
        }
        .frame(maxWidth: .infinity)
    }

    private func transportButton(icon: String, action: @escaping () -> Void) -> some View {
        PlayerButton(size: CadenceTheme.transportButtonSize, action: action) {
            Image(systemName: icon)
                .font(.system(size: 22))
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(CadenceTheme.trackBackground(for: colorScheme))
                    .frame(height: isProgressHovered ? 6 : CadenceTheme.progressBarHeight)

                Capsule()
                    .fill(CadenceTheme.accent(for: colorScheme))
                    .frame(
                        width: geometry.size.width * progressRatio,
                        height: isProgressHovered ? 6 : CadenceTheme.progressBarHeight
                    )
                    .overlay(alignment: .trailing) {
                        if isProgressHovered {
                            Circle()
                                .fill(CadenceTheme.accent(for: colorScheme))
                                .frame(width: 14, height: 14)
                                .shadow(color: .black.opacity(0.28), radius: 3, y: 1)
                                .offset(x: 7)
                        }
                    }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .onHover { isProgressHovered = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        seekProgress(at: value.location.x, width: geometry.size.width)
                    }
            )
            .animation(.easeOut(duration: 0.12), value: isProgressHovered)
        }
        .frame(height: 20)
    }

    private var rightSection: some View {
        HStack(spacing: 2) {
            PlayerButton(size: 38, isActive: uiState.isQueueOpen) {
                uiState.toggleQueue()
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18))
            }

            PlayerButton(size: 38, isActive: uiState.isEQOpen) {
                uiState.toggleEQ()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18))
            }

            HStack(spacing: 8) {
                Image(systemName: playbackController.volume == 0 ? "speaker.slash" : "speaker.wave.2")
                    .font(.system(size: 18))
                    .foregroundStyle(CadenceTheme.iconColor(for: colorScheme))

                volumeSlider
            }
            .padding(.leading, 6)
        }
        .frame(width: 230, alignment: .trailing)
    }

    private var volumeSlider: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(CadenceTheme.trackBackground(for: colorScheme))
                    .frame(height: isVolumeHovered ? 6 : CadenceTheme.volumeSliderHeight)

                Capsule()
                    .fill(CadenceTheme.volumeFill(for: colorScheme))
                    .frame(
                        width: geometry.size.width * CGFloat(playbackController.volume / 100),
                        height: isVolumeHovered ? 6 : CadenceTheme.volumeSliderHeight
                    )
                    .overlay(alignment: .trailing) {
                        if isVolumeHovered {
                            Circle()
                                .fill(CadenceTheme.volumeFill(for: colorScheme))
                                .frame(width: 14, height: 14)
                                .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                                .offset(x: 7)
                        }
                    }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .onHover { isVolumeHovered = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = min(max(value.location.x / geometry.size.width, 0), 1)
                        playbackController.volume = Double(ratio * 100)
                    }
            )
            .animation(.easeOut(duration: 0.12), value: isVolumeHovered)
        }
        .frame(width: CadenceTheme.volumeSliderWidth, height: 20)
    }

    // MARK: - Helpers

    private var progressRatio: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(min(1, playbackController.progress / duration))
    }

    private func seekProgress(at x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        let ratio = min(max(x / width, 0), 1)
        playbackController.seek(to: duration * Double(ratio))
    }

    private var heightAnimation: Animation? {
        guard !reduceMotion else { return nil }
        return .timingCurve(0.4, 0, 0.2, 1, duration: 0.38)
    }

    private var fullBarOpacityAnimation: Animation? {
        guard !reduceMotion else { return nil }
        if collapsed {
            return .easeOut(duration: 0.18)
        }
        return .easeIn(duration: 0.15).delay(0.20)
    }

    private var stripOpacityAnimation: Animation? {
        guard !reduceMotion else { return nil }
        if collapsed {
            return .easeIn(duration: 0.12).delay(0.22)
        }
        return .easeOut(duration: 0.12)
    }
}
