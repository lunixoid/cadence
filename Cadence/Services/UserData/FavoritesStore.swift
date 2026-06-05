import Foundation

@Observable
final class FavoritesStore {
    private let trackKey = "cadence.favoriteTrackIDs"
    private let albumKey = "cadence.favoriteAlbumIDs"

    private(set) var favoriteTrackIDs: Set<UUID> = []
    private(set) var favoriteAlbumIDs: Set<UUID> = []

    init() {
        load()
    }

    func isFavorite(track: Track) -> Bool {
        favoriteTrackIDs.contains(track.id)
    }

    func isFavorite(album: Album) -> Bool {
        favoriteAlbumIDs.contains(album.id)
    }

    func toggle(track: Track) {
        if favoriteTrackIDs.contains(track.id) {
            favoriteTrackIDs.remove(track.id)
        } else {
            favoriteTrackIDs.insert(track.id)
        }
        save()
    }

    func toggle(album: Album) {
        if favoriteAlbumIDs.contains(album.id) {
            favoriteAlbumIDs.remove(album.id)
        } else {
            favoriteAlbumIDs.insert(album.id)
        }
        save()
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
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Array(favoriteTrackIDs)) {
            UserDefaults.standard.set(data, forKey: trackKey)
        }
        if let data = try? JSONEncoder().encode(Array(favoriteAlbumIDs)) {
            UserDefaults.standard.set(data, forKey: albumKey)
        }
    }
}
