import Foundation

@Observable
final class FavoritesStore {
    private let trackKey = "cadence.favoriteTrackIDs"
    private let albumKey = "cadence.favoriteAlbumIDs"
    private let jellyfinTrackKey = "cadence.favoriteJellyfinItemIDs"

    private(set) var favoriteTrackIDs: Set<UUID> = []
    private(set) var favoriteAlbumIDs: Set<UUID> = []
    private(set) var favoriteJellyfinItemIDs: Set<String> = []

    init() {
        load()
    }

    func isFavorite(track: Track) -> Bool {
        if favoriteTrackIDs.contains(track.id) {
            return true
        }
        guard let itemID = JellyfinIdentity.itemID(from: track.fileURL) else {
            return false
        }
        return favoriteJellyfinItemIDs.contains(itemID)
    }

    func isFavorite(album: Album) -> Bool {
        favoriteAlbumIDs.contains(album.id)
    }

    @discardableResult
    func toggle(track: Track) -> Bool {
        let wasFavorite = isFavorite(track: track)
        let jellyfinItemID = JellyfinIdentity.itemID(from: track.fileURL)

        if wasFavorite {
            favoriteTrackIDs.remove(track.id)
            if let jellyfinItemID {
                favoriteJellyfinItemIDs.remove(jellyfinItemID)
            }
        } else {
            favoriteTrackIDs.insert(track.id)
            if let jellyfinItemID {
                favoriteJellyfinItemIDs.insert(jellyfinItemID)
            }
        }

        save()
        return !wasFavorite
    }

    func toggle(album: Album) {
        if favoriteAlbumIDs.contains(album.id) {
            favoriteAlbumIDs.remove(album.id)
        } else {
            favoriteAlbumIDs.insert(album.id)
        }
        save()
    }

    func mergeJellyfinFavorites(itemIDs: [String], library: LibraryStore) {
        guard !itemIDs.isEmpty else { return }

        var changed = false
        for itemID in itemIDs {
            guard favoriteJellyfinItemIDs.insert(itemID).inserted else { continue }
            changed = true

            if let track = library.allTracks().first(where: {
                JellyfinIdentity.itemID(from: $0.fileURL) == itemID
            }) {
                favoriteTrackIDs.insert(track.id)
            }
        }

        if changed {
            save()
        }
    }

    func migrateJellyfinItemIDs(using library: LibraryStore) {
        var changed = false

        for trackID in favoriteTrackIDs {
            guard let track = library.track(for: trackID),
                  let itemID = JellyfinIdentity.itemID(from: track.fileURL),
                  favoriteJellyfinItemIDs.insert(itemID).inserted else {
                continue
            }
            changed = true
        }

        for itemID in favoriteJellyfinItemIDs {
            guard let track = library.allTracks().first(where: {
                JellyfinIdentity.itemID(from: $0.fileURL) == itemID
            }),
                  favoriteTrackIDs.insert(track.id).inserted else {
                continue
            }
            changed = true
        }

        if changed {
            save()
        }
    }

    private func load() {
        if let trackData = UserDefaults.standard.data(forKey: trackKey),
           let ids = try? JSONDecoder().decode([UUID].self, from: trackData) {
            favoriteTrackIDs = Set(ids)
        }
        if let albumData = UserDefaults.standard.data(forKey: albumKey),
           let ids = try? JSONDecoder().decode([UUID].self, from: albumData) {
            favoriteAlbumIDs = Set(ids)
        }
        if let jellyfinData = UserDefaults.standard.data(forKey: jellyfinTrackKey),
           let ids = try? JSONDecoder().decode([String].self, from: jellyfinData) {
            favoriteJellyfinItemIDs = Set(ids)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Array(favoriteTrackIDs)) {
            UserDefaults.standard.set(data, forKey: trackKey)
        }
        if let data = try? JSONEncoder().encode(Array(favoriteAlbumIDs)) {
            UserDefaults.standard.set(data, forKey: albumKey)
        }
        if let data = try? JSONEncoder().encode(Array(favoriteJellyfinItemIDs)) {
            UserDefaults.standard.set(data, forKey: jellyfinTrackKey)
        }
    }
}
