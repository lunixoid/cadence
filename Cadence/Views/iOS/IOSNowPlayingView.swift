import SwiftUI

struct IOSNowPlayingView: View {
    @Environment(PlaybackController.self) private var playbackController
    @Environment(FavoritesStore.self) private var favoritesStore
    @Environment(JellyfinFavoritesSync.self) private var jellyfinFavoritesSync
    @Environment(AppUIState.self) private var uiState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let onOpenQueue: () -> Void

    private var album: Album? {
        playbackController.album()
    }

    private var track: Track? {
        playbackController.currentTrack
    }

    private var isFavorite: Bool {
        guard let track else { return false }
        return favoritesStore.isFavorite(track: track)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: 8)

                AlbumCoverView(
                    album: album,
                    size: 280,
                    cornerRadius: 14,
                    showVinylDisc: true
                )
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
        HStack(spacing: 36) {
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
    }
}
