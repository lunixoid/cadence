import SwiftUI

struct AlbumCoverView: View {
    let album: Album?
    var size: CGFloat = CadenceTheme.miniCoverSize
    var cornerRadius: CGFloat = CadenceTheme.miniCoverRadius

    var body: some View {
        Group {
            if let coverURL = album?.coverURL, let nsImage = NSImage(contentsOf: coverURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                AlbumCoverPlaceholderView(
                    colors: album?.accentColors ?? CadenceTheme.placeholderGradientColors,
                    size: size,
                    cornerRadius: cornerRadius
                )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
