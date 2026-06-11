import SwiftUI

struct AlbumCoverView: View {
    let album: Album?
    var size: CGFloat = CadenceTheme.miniCoverSize
    var cornerRadius: CGFloat = CadenceTheme.miniCoverRadius

    @State private var image: NSImage?
    @State private var loadGeneration = 0

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
        .id(album?.id)
        .onChange(of: album?.id, initial: true) { _, _ in
            Task { @MainActor in
                reloadCover()
            }
        }
    }

    private func reloadCover() {
        loadGeneration += 1
        let generation = loadGeneration
        guard let coverURL = album?.coverURL else {
            image = nil
            return
        }

        let maxWidth = Int(size * 2)
        Task {
            let loaded = await ArtworkCache.shared.image(for: coverURL, maxWidth: maxWidth)
            guard generation == loadGeneration else { return }
            image = loaded
        }
    }
}
