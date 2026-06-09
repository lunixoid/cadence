import Foundation
import SwiftUI
import os.log

private let logger = Logger(subsystem: "dev.personal.cadence", category: "JellyfinLoader")

@MainActor
final class JellyfinLibraryLoader {
    private let client: JellyfinClient
    private let libraryStore: LibraryStore

    init(client: JellyfinClient, libraryStore: LibraryStore) {
        self.client = client
        self.libraryStore = libraryStore
    }

    func loadFullLibrary() async {
        logger.info("Starting Jellyfin library load")
        do {
            let audioItems = try await client.getAllAudioItems()
            logger.info("Fetched \(audioItems.count) audio items from Jellyfin")

            var groupedTracks: [String: [JellyfinItem]] = [:]
            for item in audioItems {
                let key = client.albumGroupKey(for: item)
                groupedTracks[key, default: []].append(item)
            }

            var albums: [Album] = []
            var allTracks: [Track] = []

            for (_, trackItems) in groupedTracks {
                let sortedItems = sortTrackItems(trackItems)
                let albumID = client.cadenceAlbumID(for: sortedItems[0])
                guard let album = client.convertToAlbum(from: sortedItems, albumID: albumID) else { continue }

                let tracks = sortedItems.enumerated().compactMap { offset, item in
                    client.convertToTrack(item: item, albumID: album.id, positionInAlbum: offset + 1)
                }

                albums.append(album)
                allTracks.append(contentsOf: tracks)
            }

            let scanResult = LibraryScanResult(
                albums: albums.sorted { $0.title < $1.title },
                tracks: allTracks,
                artists: buildArtists(from: albums)
            )

            libraryStore.loadFromJellyfin(scanResult)
            logger.info("Jellyfin library loaded: \(albums.count) albums, \(allTracks.count) tracks")
        } catch {
            logger.error("Failed to load Jellyfin library: \(error.localizedDescription)")
        }
    }

    private func sortTrackItems(_ items: [JellyfinItem]) -> [JellyfinItem] {
        items.sorted { lhs, rhs in
            let lhsDisc = lhs.parentIndexNumber ?? 1
            let rhsDisc = rhs.parentIndexNumber ?? 1
            if lhsDisc != rhsDisc { return lhsDisc < rhsDisc }

            let lhsIndex = lhs.indexNumber ?? Int.max
            let rhsIndex = rhs.indexNumber ?? Int.max
            if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func buildArtists(from albums: [Album]) -> [Artist] {
        var map: [String: Artist] = [:]
        for album in albums {
            let name = album.artist
            if map[name] == nil {
                map[name] = Artist(name: name)
            }
            map[name]?.albumIDs.append(album.id)
        }
        return map.values.sorted { $0.name < $1.name }
    }
}
