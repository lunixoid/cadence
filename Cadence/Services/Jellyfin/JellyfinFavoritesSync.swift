import Foundation
import os.log

private let logger = Logger(subsystem: "dev.personal.cadence", category: "JellyfinFavorites")

@Observable
@MainActor
final class JellyfinFavoritesSync {
    private let favoritesStore: FavoritesStore
    private let libraryStore: LibraryStore
    private let offlineStore: OfflineStore

    init(favoritesStore: FavoritesStore, libraryStore: LibraryStore, offlineStore: OfflineStore) {
        self.favoritesStore = favoritesStore
        self.libraryStore = libraryStore
        self.offlineStore = offlineStore
    }

    func toggle(track: Track, client: JellyfinClient?) {
        let isFavorite = favoritesStore.toggle(track: track)

        if isFavorite {
            if let client {
                offlineStore.download(track: track, client: client, origin: .favorite)
            }
        } else {
            offlineStore.removeIfFavoriteOrigin(trackID: track.id)
        }

        guard let client,
              let itemID = JellyfinIdentity.itemID(from: track.fileURL) else {
            return
        }

        Task {
            do {
                if isFavorite {
                    try await client.markFavorite(itemID: itemID)
                } else {
                    try await client.unmarkFavorite(itemID: itemID)
                }
            } catch {
                logger.error("Failed to sync favorite with Jellyfin: \(error.localizedDescription)")
            }
        }
    }

    func syncFromServer(client: JellyfinClient) async {
        favoritesStore.migrateJellyfinItemIDs(using: libraryStore)

        do {
            let items = try await client.getFavoriteItems()
            favoritesStore.mergeJellyfinFavorites(
                itemIDs: items.map(\.id),
                library: libraryStore
            )
        } catch {
            logger.error("Failed to fetch Jellyfin favorites: \(error.localizedDescription)")
        }
    }
}
