import SwiftUI

struct AlbumCardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let album: Album
    var onTap: () -> Void
    var onPlay: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    AlbumCoverView(
                        album: album,
                        size: CadenceTheme.albumCardWidth - 12,
                        cornerRadius: CadenceTheme.albumCardRadius
                    )

                    if isHovered {
                        Button(action: onPlay) {
                            Circle()
                                .fill(Color.black.opacity(0.55))
                                .background(.ultraThinMaterial, in: Circle())
                                .frame(width: CadenceTheme.playOverlaySize, height: CadenceTheme.playOverlaySize)
                                .overlay {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white)
                                }
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
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
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
