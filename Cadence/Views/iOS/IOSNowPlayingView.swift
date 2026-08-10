import SwiftUI

struct IOSNowPlayingView: View {
    @Environment(PlaybackController.self) private var playbackController
    @Environment(FavoritesStore.self) private var favoritesStore
    @Environment(JellyfinFavoritesSync.self) private var jellyfinFavoritesSync
    @Environment(AppUIState.self) private var uiState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let onOpenQueue: () -> Void

    private static let centerCoverSize: CGFloat = 280
    private static let coverSpacing: CGFloat = 16
    private static let nearScale: CGFloat = 0.88
    private static let farScale: CGFloat = 0.78

    @State private var coverDragX: CGFloat = 0

    private var album: Album? {
        playbackController.album()
    }

    private var track: Track? {
        playbackController.currentTrack
    }

    private var stripNeighbors: (previous: [Track], next: [Track]) {
        playbackController.coverStripTracks(before: 2, after: 2)
    }

    private var isFavorite: Bool {
        guard let track else { return false }
        return favoritesStore.isFavorite(track: track)
    }

    private var slotPitch: CGFloat {
        Self.centerCoverSize + Self.coverSpacing
    }

    /// -1…1: positive = dragging toward previous (right), negative = toward next (left).
    private var swipeProgress: CGFloat {
        min(max(coverDragX / slotPitch, -1), 1)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: 8)

                coverStrip
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.centerCoverSize)
                    .clipped()
                    .contentShape(Rectangle())
                    .gesture(coverSwipeGesture)
                    .accessibilityHint("Смахните влево или вправо, чтобы сменить трек")
                    .padding(.bottom, 28)

                VStack(spacing: 6) {
                    Text(track?.title ?? "—")
                        .font(.system(size: 22, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(track?.artist ?? "—")
                        .font(.system(size: 15))
                        .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                }
                .padding(.horizontal, 24)

                HStack {
                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 20))
                            .foregroundStyle(
                                isFavorite
                                    ? Color(red: 1, green: 0.216, blue: 0.373)
                                    : CadenceTheme.secondaryText(for: colorScheme)
                            )
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(action: onOpenQueue) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 18))
                            .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)

                seekSection
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                transport
                    .padding(.top, 12)

                Spacer()
            }
            .background {
                LinearGradient(
                    colors: [
                        (album?.accentColors.first ?? CadenceTheme.placeholderGradientColors[0]).opacity(0.35),
                        CadenceTheme.contentBackground(for: colorScheme)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Сейчас играет")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
        }
    }

    private var coverStripSlots: [CoverStripSlot] {
        let neighbors = stripNeighbors
        let prevTracks = neighbors.previous
        let nextTracks = neighbors.next
        let prev2 = prevTracks.count >= 2 ? prevTracks[prevTracks.count - 2] : nil
        let prev1 = prevTracks.last
        let next1 = nextTracks.first
        let next2 = nextTracks.count >= 2 ? nextTracks[1] : nil

        func slot(track: Track?, album: Album?, index: Int) -> CoverStripSlot {
            CoverStripSlot(
                id: track?.id ?? CoverStripSlot.emptyID(for: index),
                track: track,
                album: album,
                index: index
            )
        }

        return [
            slot(track: prev2, album: playbackController.album(forCurrentTrack: prev2), index: -2),
            slot(track: prev1, album: playbackController.album(forCurrentTrack: prev1), index: -1),
            slot(track: track, album: album, index: 0),
            slot(track: next1, album: playbackController.album(forCurrentTrack: next1), index: 1),
            slot(track: next2, album: playbackController.album(forCurrentTrack: next2), index: 2)
        ]
    }

    private var coverStrip: some View {
        let progress = swipeProgress
        let slots = coverStripSlots

        // Overlay keeps the 5-wide HStack from expanding the sheet layout width
        // (otherwise seek/favorite/queue controls are pushed off-screen).
        return Color.clear
            .overlay {
                HStack(spacing: Self.coverSpacing) {
                    ForEach(slots) { slot in
                        coverSlot(
                            slot: slot,
                            scale: scale(for: slot.index, progress: progress)
                        )
                    }
                }
                .offset(x: coverDragX)
            }
    }

    /// Rest scales: −2/＋2 → 0.78, −1/＋1 → 0.88, 0 → 1. Interpolate toward neighbor on swipe.
    private func scale(for slot: Int, progress: CGFloat) -> CGFloat {
        let rest: CGFloat
        switch abs(slot) {
        case 0: rest = 1
        case 1: rest = Self.nearScale
        default: rest = Self.farScale
        }

        let targetSlot = progress > 0 ? -1 : (progress < 0 ? 1 : 0)
        guard targetSlot != 0 else { return rest }

        let t = abs(progress)
        let targetRest: CGFloat
        switch abs(slot - targetSlot) {
        case 0: targetRest = 1
        case 1: targetRest = Self.nearScale
        default: targetRest = Self.farScale
        }

        return rest + (targetRest - rest) * t
    }

    @ViewBuilder
    private func coverSlot(slot: CoverStripSlot, scale: CGFloat) -> some View {
        Group {
            if slot.track != nil {
                AlbumCoverView(
                    album: slot.album,
                    size: Self.centerCoverSize,
                    cornerRadius: 14
                )
            } else {
                Color.clear.frame(width: Self.centerCoverSize, height: Self.centerCoverSize)
            }
        }
        .scaleEffect(scale)
        .frame(width: Self.centerCoverSize, height: Self.centerCoverSize)
    }

    private var coverSwipeGesture: some Gesture {
        let pitch = slotPitch
        let commitDistance = pitch * 0.5
        let snapAnimation = Animation.spring(response: 0.32, dampingFraction: 0.82)

        return DragGesture(minimumDistance: 16)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy) else {
                    coverDragX = 0
                    return
                }
                coverDragX = dx
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let isHorizontal = abs(dx) > abs(dy)
                let neighbors = stripNeighbors

                if isHorizontal, abs(dx) >= commitDistance {
                    if dx < 0, !neighbors.next.isEmpty {
                        finishCoverPageChange(targetOffset: -pitch, animation: snapAnimation) {
                            playbackController.next()
                        }
                        return
                    }
                    if dx > 0, !neighbors.previous.isEmpty {
                        finishCoverPageChange(targetOffset: pitch, animation: snapAnimation) {
                            playbackController.skipToPreviousTrack()
                        }
                        return
                    }
                }

                withAnimation(snapAnimation) {
                    coverDragX = 0
                }
            }
    }

    private func finishCoverPageChange(
        targetOffset: CGFloat,
        animation: Animation,
        change: @escaping () -> Void
    ) {
        withAnimation(animation) {
            coverDragX = targetOffset
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                coverDragX = 0
                change()
            }
        }
    }

    private var seekSection: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { playbackController.progress },
                    set: { playbackController.seek(to: $0) }
                ),
                in: 0...max(playbackController.duration, 0.1)
            )
            .tint(CadenceTheme.accent(for: colorScheme))

            HStack {
                Text(CadenceTheme.formatTime(playbackController.progress))
                Spacer()
                Text(CadenceTheme.formatTime(playbackController.duration))
            }
            .font(.system(size: 12).monospacedDigit())
            .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
        }
    }

    private var transport: some View {
        HStack(spacing: 28) {
            Button {
                playbackController.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        playbackController.shuffleOn
                            ? CadenceTheme.accent(for: colorScheme)
                            : CadenceTheme.primaryText(for: colorScheme)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Перемешать")

            Button {
                playbackController.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28))
            }
            .buttonStyle(.plain)

            Button {
                playbackController.togglePlayPause()
            } label: {
                Image(systemName: playbackController.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(playIconColor)
                    .frame(width: 72, height: 72)
                    .background(playButtonFill, in: Circle())
            }
            .buttonStyle(.plain)

            Button {
                playbackController.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28))
            }
            .buttonStyle(.plain)

            Button {
                playbackController.toggleRepeat()
            } label: {
                Image(systemName: playbackController.repeatMode.iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(
                        playbackController.repeatMode != .off
                            ? CadenceTheme.accent(for: colorScheme)
                            : CadenceTheme.primaryText(for: colorScheme)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Повтор")
        }
        .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
    }

    private var playButtonFill: Color {
        colorScheme == .dark ? .white : Color(red: 0.11, green: 0.11, blue: 0.118)
    }

    private var playIconColor: Color {
        colorScheme == .dark ? Color(red: 0.11, green: 0.11, blue: 0.118) : .white
    }

    private func toggleFavorite() {
        guard let track else { return }
        jellyfinFavoritesSync.toggle(track: track, client: uiState.activeJellyfinClient)
        playbackController.refreshNowPlayingInfo()
    }
}

private struct CoverStripSlot: Identifiable {
    let id: UUID
    let track: Track?
    let album: Album?
    let index: Int

    static func emptyID(for index: Int) -> UUID {
        // Stable sentinels for empty −2…+2 slots (not real track IDs).
        switch index {
        case -2: return UUID(uuidString: "00000000-0000-4000-8000-0000000000E2")!
        case -1: return UUID(uuidString: "00000000-0000-4000-8000-0000000000E1")!
        case 1: return UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        case 2: return UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        default: return UUID(uuidString: "00000000-0000-4000-8000-000000000000")!
        }
    }
}
