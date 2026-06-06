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
            let albumItems = try await client.getAlbums(limit: 10000)
            logger.info("Fetched \(albumItems.count) albums from Jellyfin")

            var albums: [Album] = []
            var allTracks: [Track] = []
            var tracksByAlbumID: [UUID: [Track]] = [:]

            await withTaskGroup(of: (Album, [Track]).self) { group in
                for item in albumItems {
                    group.addTask {
                        let album = await self.client.convertToAlbum(item: item)
                        let trackItems = (try? await self.client.getAlbumTracks(albumID: item.id)) ?? []
                        let tracks = trackItems.compactMap { self.client.convertToTrack(item: $0, albumID: album.id) }
                        return (album, tracks)
                    }
                }

                for await (album, tracks) in group {
                    albums.append(album)
                    allTracks.append(contentsOf: tracks)
                    tracksByAlbumID[album.id] = tracks
                }
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
