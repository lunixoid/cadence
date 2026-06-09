import Foundation
import os.log

private let logger = Logger(subsystem: "dev.personal.cadence", category: "JellyfinLibraryCache")

// MARK: - DTO

struct CachedAlbum: Codable {
    let id: UUID
    var title: String
    var artist: String
    var year: Int?
    var coverURL: URL?
    var artworkItemID: String?

    func toAlbum() -> Album {
        var resolvedCoverURL = coverURL
        if let itemID = artworkItemID,
           let local = ArtworkCache.cachedFileURL(itemID: itemID, maxWidth: 300) {
            resolvedCoverURL = local
        }
        return Album(
            id: id,
            title: title,
            artist: artist,
            year: year,
            coverURL: resolvedCoverURL
        )
    }

    static func from(_ album: Album, artworkItemID: String?) -> CachedAlbum {
        CachedAlbum(
            id: album.id,
            title: album.title,
            artist: album.artist,
            year: album.year,
            coverURL: album.coverURL,
            artworkItemID: artworkItemID
        )
    }
}

struct CachedTrack: Codable {
    let id: UUID
    var index: Int
    var title: String
    var artist: String
    var albumID: UUID
    var duration: TimeInterval
    var fileURL: URL
    var discNumber: Int

    func toTrack() -> Track {
        Track(
            id: id,
            index: index,
            title: title,
            artist: artist,
            albumID: albumID,
            duration: duration,
            fileURL: fileURL,
            discNumber: discNumber
        )
    }

    static func from(_ track: Track) -> CachedTrack {
        CachedTrack(
            id: track.id,
            index: track.index,
            title: track.title,
            artist: track.artist,
            albumID: track.albumID,
            duration: track.duration,
            fileURL: track.fileURL,
            discNumber: track.discNumber
        )
    }
}

struct CachedArtist: Codable {
    let id: String
    var name: String
    var albumIDs: [UUID]

    func toArtist() -> Artist {
        Artist(name: name, albumIDs: albumIDs)
    }

    static func from(_ artist: Artist) -> CachedArtist {
        CachedArtist(id: artist.id, name: artist.name, albumIDs: artist.albumIDs)
    }
}

private struct CachedLibrarySnapshot: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var cachedAt: Date
    var albums: [CachedAlbum]
    var tracks: [CachedTrack]
    var artists: [CachedArtist]

    func toLibraryScanResult() -> LibraryScanResult {
        LibraryScanResult(
            albums: albums.map { $0.toAlbum() },
            tracks: tracks.map { $0.toTrack() },
            artists: artists.map { $0.toArtist() }
        )
    }
}

// MARK: - Cache

enum JellyfinLibraryCache {
    private static let schemaVersion = CachedLibrarySnapshot.currentSchemaVersion

    private static var baseDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Cadence/jellyfin", isDirectory: true)
    }

    private static func cacheURL(serverID: UUID) -> URL {
        baseDirectory
            .appendingPathComponent(serverID.uuidString, isDirectory: true)
            .appendingPathComponent("library.json")
    }

    static func load(serverID: UUID) -> LibraryScanResult? {
        let url = cacheURL(serverID: serverID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let snapshot = try JSONDecoder().decode(CachedLibrarySnapshot.self, from: data)
            guard snapshot.schemaVersion == schemaVersion else {
                logger.info("Ignoring stale Jellyfin library cache (schema \(snapshot.schemaVersion))")
                return nil
            }
            logger.info("Loaded Jellyfin library cache: \(snapshot.albums.count) albums")
            return snapshot.toLibraryScanResult()
        } catch {
            logger.error("Failed to load Jellyfin library cache: \(error.localizedDescription)")
            return nil
        }
    }

    static func save(
        _ result: LibraryScanResult,
        serverID: UUID,
        artworkItemIDs: [UUID: String]
    ) {
        let snapshot = CachedLibrarySnapshot(
            schemaVersion: schemaVersion,
            cachedAt: Date(),
            albums: result.albums.map { CachedAlbum.from($0, artworkItemID: artworkItemIDs[$0.id]) },
            tracks: result.tracks.map { CachedTrack.from($0) },
            artists: result.artists.map { CachedArtist.from($0) }
        )

        let url = cacheURL(serverID: serverID)
        let directory = url.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
            logger.info("Saved Jellyfin library cache: \(result.albums.count) albums")
        } catch {
            logger.error("Failed to save Jellyfin library cache: \(error.localizedDescription)")
        }
    }

    static func remove(serverID: UUID) {
        let directory = baseDirectory.appendingPathComponent(serverID.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
    }

    static func clearAll() {
        try? FileManager.default.removeItem(at: baseDirectory)
    }

    static func diskUsageBytes() -> Int64 {
        directorySize(at: baseDirectory)
    }

    private static func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
        return total
    }
}
