import SwiftUI

struct AlbumCoverView: View {
    let album: Album?
    var size: CGFloat = CadenceTheme.miniCoverSize
    var cornerRadius: CGFloat = CadenceTheme.miniCoverRadius

    @State private var image: NSImage?
    @State private var imageAlbumID: UUID?
    @State private var loadGeneration = 0

    var body: some View {
        Group {
            if let image, imageAlbumID == album?.id {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .id(imageAlbumID)
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
        .onChange(of: album?.id, initial: true) { _, newID in
            if imageAlbumID != newID {
                image = nil
                imageAlbumID = nil
            }
            reloadCover()
        }
    }

    private func reloadCover() {
        loadGeneration += 1
        let generation = loadGeneration
        guard let coverURL = album?.coverURL, let albumID = album?.id else {
            image = nil
            imageAlbumID = nil
            return
        }

        let maxWidth = Int(size * 2)
        Task { @MainActor in
            let loaded = await ArtworkCache.shared.image(for: coverURL, maxWidth: maxWidth)
            guard generation == loadGeneration else { return }
            image = loaded
            imageAlbumID = loaded != nil ? albumID : nil
        }
    }
}
