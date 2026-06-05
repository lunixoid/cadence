import SwiftUI

struct AlbumCoverPlaceholderView: View {
    var colors: [Color] = CadenceTheme.placeholderGradientColors
    var size: CGFloat = CadenceTheme.albumCoverSize
    var cornerRadius: CGFloat = CadenceTheme.albumCoverRadius
    var showVinylHint: Bool = true

    var body: some View {
        let gradientColors = colors.count >= 3 ? colors : CadenceTheme.placeholderGradientColors

        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [gradientColors[0], gradientColors[1], gradientColors[2]],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if showVinylHint {
                vinylHint(scale: size / CadenceTheme.albumCoverSize)
            }

            Ellipse()
                .fill(Color.white.opacity(0.08))
                .frame(width: size * 0.47, height: size * 0.34)
                .offset(x: -size * 0.05, y: -size * 0.22)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func vinylHint(scale: CGFloat) -> some View {
        let outer = 56 * scale
        let middle = 22 * scale
        let inner = 8 * scale

        ZStack {
            Circle()
                .fill(Color.black.opacity(0.15))
                .frame(width: outer, height: outer)

            Circle()
                .fill(Color.black.opacity(0.25))
                .frame(width: middle, height: middle)

            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: inner, height: inner)
        }
    }
}
