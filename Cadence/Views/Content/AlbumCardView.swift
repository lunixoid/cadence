import SwiftUI

struct AlbumCardView: View {
    @Environment(PlaybackController.self) private var playbackController
    @Environment(\.colorScheme) private var colorScheme

    let album: Album
    var onTap: () -> Void

    @State private var isHovered = false

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
    }

    private func handlePlay() {
        playbackController.playAlbum(album, shuffled: false)
    }
}
