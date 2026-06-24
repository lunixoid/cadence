import SwiftUI

struct NowPlayingDetailView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(PlaybackController.self) private var playbackController
    @Environment(FavoritesStore.self) private var favoritesStore
    @Environment(JellyfinFavoritesSync.self) private var jellyfinFavoritesSync
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPlayHovered = false

    private var track: Track? { playbackController.currentTrack }
    private var album: Album? { playbackController.album() }

    private var duration: TimeInterval {
        max(playbackController.duration, track?.duration ?? 1, 1)
    }

    private var upNextDisplayTracks: [Track] {
        let explicit = playbackController.upNextTracks
        let autoplay = playbackController.autoplayPreviewTracks(limit: .max)
        return explicit + autoplay
    }

    var body: some View {
        LibraryContentShell {
            if let track, let album {
                GeometryReader { geometry in
                    let isWide = geometry.size.width >= CadenceTheme.nowPlayingWideThreshold

                    ZStack {
                        NowPlayingAtmosphericBackground(
                            albumID: album.id,
                            colors: album.accentColors,
                            colorScheme: colorScheme,
                            reduceMotion: reduceMotion
                        )

                        if isWide {
                            wideLayout(track: track, album: album, containerWidth: geometry.size.width)
                        } else {
                            narrowLayout(track: track, album: album, containerWidth: geometry.size.width)
                        }
                    }
                }
            } else {
                EmptyLibraryStateView(message: "Сейчас ничего не играет")
            }
        }
    }

    // MARK: - Layouts

    private func wideLayout(track: Track, album: Album, containerWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            controlsColumn(track: track, album: album, containerWidth: containerWidth, isWide: true)
                .frame(maxWidth: .infinity)

            rightPanel(track: track, album: album)
                .frame(width: CadenceTheme.nowPlayingRightPanelWidth)
        }
    }

    private func narrowLayout(track: Track, album: Album, containerWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            controlsColumn(track: track, album: album, containerWidth: containerWidth, isWide: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            narrowUpNextPanel()
        }
    }

    private func controlsColumn(
        track: Track,
        album: Album,
        containerWidth: CGFloat,
        isWide: Bool
    ) -> some View {
        let coverSize = heroCoverSize(containerWidth: containerWidth, isWide: isWide)
        let controlMaxWidth = max(coverSize + 48, 340)

        return ScrollView {
            VStack(spacing: 22) {
                heroCover(album: album, size: coverSize)

                trackInfo(track: track, album: album, maxWidth: controlMaxWidth)

                NowPlayingSeekBar(
                    progress: playbackController.progress,
                    duration: duration,
                    colorScheme: colorScheme,
                    onSeek: { playbackController.seek(to: $0) }
                )
                .frame(maxWidth: controlMaxWidth)

                transportControls

                actionRow
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, isWide ? 48 : 24)
            .padding(.vertical, isWide ? 40 : 28)
        }
    }

    private func heroCover(album: Album, size: CGFloat) -> some View {
        NowPlayingHeroCover(
            album: album,
            size: size,
            isPlaying: playbackController.isPlaying,
            reduceMotion: reduceMotion
        )
    }

    private func trackInfo(track: Track, album: Album, maxWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text(track.title)
                .font(.system(size: 26, weight: .bold))
                .kerning(-0.025 * 26)
                .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                .lineLimit(1)
                .frame(maxWidth: maxWidth)

            Text(track.artist)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(CadenceTheme.accent(for: colorScheme))
                .lineLimit(1)
                .padding(.top, 5)
                .frame(maxWidth: maxWidth)

            Text(album.title)
                .font(.system(size: 13))
                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                .lineLimit(1)
                .padding(.top, 3)
                .frame(maxWidth: maxWidth)
        }
        .multilineTextAlignment(.center)
    }

    private var transportControls: some View {
        HStack(spacing: 2) {
            PlayerButton(size: 44, isActive: playbackController.shuffleOn) {
                playbackController.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 22))
            }

            transportButton(icon: "backward.fill", size: 48) {
                playbackController.previous()
            }

            playPauseButton

            transportButton(icon: "forward.fill", size: 48) {
                playbackController.next()
            }

            PlayerButton(size: 44, isActive: playbackController.repeatMode != .off) {
                playbackController.toggleRepeat()
            } label: {
                Image(systemName: playbackController.repeatMode.iconName)
                    .font(.system(size: 22))
            }
        }
    }

    private var playPauseButton: some View {
        Image(systemName: playbackController.isPlaying ? "pause.fill" : "play.fill")
            .font(.system(size: 26))
            .foregroundStyle(colorScheme == .dark ? Color(red: 0.11, green: 0.11, blue: 0.12) : .white)
            .frame(width: 72, height: 72)
            .background(CadenceTheme.primaryText(for: colorScheme))
            .clipShape(Circle())
            .scaleEffect(isPlayHovered ? 1.06 : 1)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.52 : 0.16), radius: 11, y: 4)
            .contentShape(Circle())
            .onTapGesture {
                playbackController.togglePlayPause()
            }
            .onHover { isPlayHovered = $0 }
            .animation(.easeOut(duration: 0.1), value: isPlayHovered)
    }

    private func transportButton(
        icon: String,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        PlayerButton(size: size, action: action) {
            Image(systemName: icon)
                .font(.system(size: 26))
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            PlayerButton(
                size: 36,
                isActive: isCurrentTrackFavorite
            ) {
                guard let track = playbackController.currentTrack else { return }
                jellyfinFavoritesSync.toggle(track: track, client: uiState.activeJellyfinClient)
            } label: {
                Image(systemName: isCurrentTrackFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        isCurrentTrackFavorite
                            ? Color(red: 1, green: 0.216, blue: 0.373)
                            : CadenceTheme.mutedText(for: colorScheme)
                    )
            }

            NowPlayingActionPill(
                icon: "opticaldisc",
                label: "К альбому",
                colorScheme: colorScheme,
                action: {
                    guard let album = playbackController.album() else { return }
                    uiState.openAlbum(album)
                }
            )

            NowPlayingActionPill(
                icon: "person",
                label: "К артисту",
                colorScheme: colorScheme,
                action: {
                    guard let artist = playbackController.currentTrack?.artist else { return }
                    uiState.openArtist(artist)
                }
            )
        }
        .id(track?.id)
    }

    private var isCurrentTrackFavorite: Bool {
        guard let track = playbackController.currentTrack else { return false }
        return favoritesStore.isFavorite(track: track)
    }

    private func rightPanel(track: Track, album: Album) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                upNextSection(showFullTitle: true)
                    .padding(.horizontal, 12)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
            }

            Rectangle()
                .fill(CadenceTheme.borderColor(for: colorScheme))
                .frame(height: 0.5)

            SpectrumVisualizerView(
                analyzer: playbackController.spectrumAnalyzer,
                isPlaying: playbackController.isPlaying
            )
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(CadenceTheme.borderColor(for: colorScheme))
                .frame(width: 0.5)
        }
    }

    private func narrowUpNextPanel() -> some View {
        VStack(spacing: 0) {
            ScrollView {
                upNextSection(showFullTitle: false)
                    .padding(.horizontal, 12)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
            }
            .frame(maxHeight: 200)
        }
        .background(
            colorScheme == .dark
                ? Color.black.opacity(0.15)
                : Color.white.opacity(0.15)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CadenceTheme.borderColor(for: colorScheme))
                .frame(height: 0.5)
        }
    }

    private func upNextSection(showFullTitle: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(showFullTitle ? "Далее в очереди" : "Далее")
                .font(.system(size: 11, weight: .bold))
                .kerning(0.06 * 11)
                .foregroundStyle(CadenceTheme.mutedText(for: colorScheme))
                .textCase(.uppercase)
                .padding(.horizontal, 12)
                .padding(.bottom, showFullTitle ? 8 : 6)

            let tracks = upNextDisplayTracks
            if tracks.isEmpty {
                Text("Нет треков")
                    .font(.system(size: 12))
                    .italic()
                    .foregroundStyle(CadenceTheme.mutedText(for: colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            } else {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, upNextTrack in
                    NowPlayingUpNextRow(
                        track: upNextTrack,
                        index: index + 1,
                        colorScheme: colorScheme,
                        onDoubleClick: { playUpNextItem(at: index) }
                    )
                }
            }
        }
    }

    private func heroCoverSize(containerWidth: CGFloat, isWide: Bool) -> CGFloat {
        if isWide {
            return min(CadenceTheme.nowPlayingHeroCoverSize, floor(containerWidth * 0.28))
        }
        return min(220, floor(containerWidth * 0.55))
    }

    private func playUpNextItem(at index: Int) {
        let explicitCount = playbackController.upNextTracks.count
        if index < explicitCount {
            playbackController.playUpNext(at: index)
            return
        }

        let autoplayIndex = index - explicitCount
        let autoplay = playbackController.autoplayPreviewTracks(limit: .max)
        guard autoplayIndex < autoplay.count else { return }
        playbackController.playTrack(autoplay[autoplayIndex])
    }
}

// MARK: - Atmospheric Background

private struct NowPlayingAtmosphericBackground: View {
    let albumID: UUID
    let colors: [Color]
    let colorScheme: ColorScheme
    let reduceMotion: Bool

    @State private var displayColors: [Color]
    @State private var blobOpacity: Double = 1

    init(albumID: UUID, colors: [Color], colorScheme: ColorScheme, reduceMotion: Bool) {
        self.albumID = albumID
        self.colors = colors
        self.colorScheme = colorScheme
        self.reduceMotion = reduceMotion
        _displayColors = State(initialValue: colors)
    }

    var body: some View {
        ZStack {
            blobLayer
                .opacity(blobOpacity)

            Rectangle()
                .fill(overlayColor)
        }
        .onChange(of: albumID) { _, _ in
            guard !reduceMotion else {
                displayColors = colors
                return
            }
            withAnimation(.easeInOut(duration: 0.25)) {
                blobOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
                displayColors = colors
                withAnimation(.easeInOut(duration: 0.5)) {
                    blobOpacity = 1
                }
            }
        }
    }

    private var overlayColor: Color {
        colorScheme == .dark
            ? Color(red: 20 / 255, green: 20 / 255, blue: 23 / 255).opacity(0.60)
            : Color(red: 244 / 255, green: 244 / 255, blue: 248 / 255).opacity(0.74)
    }

    private var blobLayer: some View {
        GeometryReader { geometry in
            let palette = displayColors.count >= 3
                ? displayColors
                : CadenceTheme.placeholderGradientColors

            ZStack {
                blob(
                    color: palette[0].opacity(0.78),
                    width: geometry.size.width * 0.70,
                    height: geometry.size.height * 0.70,
                    offset: CGSize(width: -geometry.size.width * 0.12, height: -geometry.size.height * 0.18),
                    blur: 68
                )

                blob(
                    color: palette[1].opacity(0.66),
                    width: geometry.size.width * 0.58,
                    height: geometry.size.height * 0.58,
                    offset: CGSize(width: geometry.size.width * 0.08, height: geometry.size.height * 0.14),
                    blur: 84
                )

                blob(
                    color: palette[2].opacity(0.53),
                    width: geometry.size.width * 0.48,
                    height: geometry.size.height * 0.48,
                    offset: CGSize(width: geometry.size.width * 0.22, height: -geometry.size.height * 0.04),
                    blur: 96
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func blob(
        color: Color,
        width: CGFloat,
        height: CGFloat,
        offset: CGSize,
        blur: CGFloat
    ) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(width, height) * 0.5
                )
            )
            .frame(width: width, height: height)
            .offset(offset)
            .blur(radius: blur)
    }
}

// MARK: - Hero Cover

private struct NowPlayingHeroCover: View {
    let album: Album
    let size: CGFloat
    let isPlaying: Bool
    let reduceMotion: Bool

    @State private var breathPhase = false

    var body: some View {
        AlbumCoverView(
            album: album,
            size: size,
            cornerRadius: 14
        )
        .shadow(
            color: (album.accentColors.count > 1 ? album.accentColors[1] : .black).opacity(0.35),
            radius: 30,
            y: 18
        )
        .shadow(color: .black.opacity(0.28), radius: 9, y: 4)
        .scaleEffect(breathScale)
        .onAppear { startBreathing() }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                startBreathing()
            } else {
                breathPhase = false
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 3.5).repeatForever(autoreverses: true),
            value: breathPhase
        )
    }

    private var breathScale: CGFloat {
        guard isPlaying, !reduceMotion, breathPhase else { return 1 }
        return 1.025
    }

    private func startBreathing() {
        guard isPlaying, !reduceMotion else { return }
        breathPhase = true
    }
}

// MARK: - Seek Bar

private struct NowPlayingSeekBar: View {
    let progress: TimeInterval
    let duration: TimeInterval
    let colorScheme: ColorScheme
    let onSeek: (TimeInterval) -> Void

    @State private var isHovered = false
    @State private var isDragging = false
    @State private var scrubPosition: TimeInterval?

    private var active: Bool { isHovered || isDragging }

    private var displayedProgress: TimeInterval {
        scrubPosition ?? progress
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(CadenceTheme.formatTime(displayedProgress))
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                .frame(minWidth: 34, alignment: .trailing)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(CadenceTheme.trackBackground(for: colorScheme))
                        .frame(height: active ? 5 : 3)

                    Capsule()
                        .fill(CadenceTheme.accent(for: colorScheme))
                        .frame(
                            width: geometry.size.width * progressRatio,
                            height: active ? 5 : 3
                        )
                        .overlay(alignment: .trailing) {
                            if active {
                                Circle()
                                    .fill(CadenceTheme.accent(for: colorScheme))
                                    .frame(width: 14, height: 14)
                                    .shadow(color: .black.opacity(0.32), radius: 3, y: 1)
                                    .offset(x: 7)
                            }
                        }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .onHover { isHovered = $0 }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            scrubPosition = seekTime(at: value.location.x, width: geometry.size.width)
                        }
                        .onEnded { _ in
                            if let scrubPosition {
                                onSeek(scrubPosition)
                            }
                            isDragging = false
                            scrubPosition = nil
                        }
                )
            }
            .frame(height: 20)

            Text(CadenceTheme.formatTime(duration))
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                .frame(minWidth: 34, alignment: .leading)
        }
        .animation(.easeOut(duration: 0.12), value: active)
    }

    private var progressRatio: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(min(1, displayedProgress / duration))
    }

    private func seekTime(at x: CGFloat, width: CGFloat) -> TimeInterval {
        guard width > 0 else { return 0 }
        let ratio = min(max(x / width, 0), 1)
        return duration * Double(ratio)
    }
}

// MARK: - Action Pill

private struct NowPlayingActionPill: View {
    let icon: String
    let label: String
    let colorScheme: ColorScheme
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(label)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
        .padding(.horizontal, 13)
        .padding(.vertical, 5)
        .background(
            isHovered
                ? CadenceTheme.sidebarHoverBackground(for: colorScheme)
                : CadenceTheme.secondaryButtonBackground(for: colorScheme)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(CadenceTheme.borderColor(for: colorScheme), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .onTapGesture(perform: action)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Up Next Row

private struct NowPlayingUpNextRow: View {
    let track: Track
    let index: Int
    let colorScheme: ColorScheme
    let onDoubleClick: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if isHovered {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                } else {
                    Text("\(index)")
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                }
            }
            .frame(width: 18)

            VStack(alignment: .leading, spacing: 0) {
                Text(track.title)
                    .font(.system(size: 13))
                    .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                    .lineLimit(1)

                if !track.artist.isEmpty {
                    Text(track.artist)
                        .font(.system(size: 11))
                        .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Text(CadenceTheme.formatTime(track.duration))
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isHovered ? CadenceTheme.rowHoverBackground(for: colorScheme) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2, perform: onDoubleClick)
        .animation(.easeOut(duration: 0.10), value: isHovered)
    }
}

