import SwiftUI

struct AlbumCoverView: View {
    let album: Album?
    var size: CGFloat = CadenceTheme.miniCoverSize
    var cornerRadius: CGFloat = CadenceTheme.miniCoverRadius

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
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
        .task(id: album?.coverURL) {
            guard let coverURL = album?.coverURL else {
                image = nil
                return
            }
            let loaded = await Task.detached(priority: .userInitiated) {
                NSImage(contentsOf: coverURL)
            }.value
            if !Task.isCancelled {
                image = loaded
            }
        }
    }
}
