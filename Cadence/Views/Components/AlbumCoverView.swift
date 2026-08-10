import CoreGraphics
import SwiftUI

struct AlbumCoverView: View {
    let album: Album?
    var size: CGFloat = CadenceTheme.miniCoverSize
    var cornerRadius: CGFloat = CadenceTheme.miniCoverRadius
    var showVinylDisc: Bool = false

    @State private var image: CGImage?
    @State private var imageAlbumID: UUID?
    @State private var loadGeneration = 0

    var body: some View {
        ZStack {
            if showVinylDisc {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.55),
                                Color.black.opacity(0.35),
                                Color.black.opacity(0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size * 0.92, height: size * 0.92)
                    .offset(x: size * 0.18)
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            .frame(width: size * 0.22, height: size * 0.22)
                            .offset(x: size * 0.18)
                    }
            }

            Group {
                if let image, imageAlbumID == album?.id {
                    Image(decorative: image, scale: 1)
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
        }
        .frame(width: showVinylDisc ? size * 1.18 : size, height: size, alignment: .leading)
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
