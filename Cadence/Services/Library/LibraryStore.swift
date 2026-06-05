import Foundation
import os.log

private let logger = Logger(subsystem: "dev.personal.cadence", category: "LibraryStore")

struct LibraryScanResult {
    var albums: [Album]
    var tracks: [Track]
    var artists: [Artist]
    var genres: [Genre]
}

@Observable
final class LibraryStore {
    private(set) var albums: [Album] = []
    private(set) var tracks: [Track] = []
    private(set) var artists: [Artist] = []
    private(set) var genres: [Genre] = []
    private(set) var rootFolderURL: URL?

    private var tracksByAlbumID: [UUID: [Track]] = [:]
    private var tracksByID: [UUID: Track] = [:]
    private var albumsByID: [UUID: Album] = [:]

    private let scanner = LocalLibraryScanner()
    private var securityScopedURL: URL?

    @MainActor
    func loadFolder(_ url: URL) async {
        stopAccessingSecurityScopedResource()

        let didStartAccess = url.startAccessingSecurityScopedResource()
        if didStartAccess {
            securityScopedURL = url
        }

        rootFolderURL = url

        do {
            let result = try await scanner.scan(folder: url)
            applyScanResult(result)
            logger.info("Loaded library: \(result.albums.count) albums, \(result.tracks.count) tracks")
        } catch {
            logger.error("Failed to scan folder: \(error.localizedDescription)")
            clearLibrary()
        }
    }

    #if DEBUG
    @MainActor
    func loadPreview(result: LibraryScanResult) {
        applyScanResult(result)
    }
    #endif

    func clearLibrary() {
        albums = []
        tracks = []
        artists = []
        genres = []
        tracksByAlbumID = [:]
        tracksByID = [:]
        albumsByID = [:]
    }

    func album(for id: UUID) -> Album? {
        albumsByID[id]
    }

    func track(for id: UUID) -> Track? {
        tracksByID[id]
    }

    func tracks(for album: Album) -> [Track] {
        tracksByAlbumID[album.id] ?? []
    }

    func tracks(forAlbumID id: UUID) -> [Track] {
        tracksByAlbumID[id] ?? []
    }

    func allTracks() -> [Track] {
        tracks.sorted { lhs, rhs in
            let lhsAlbum = albumsByID[lhs.albumID]?.title ?? ""
            let rhsAlbum = albumsByID[rhs.albumID]?.title ?? ""
            if lhsAlbum != rhsAlbum { return lhsAlbum.localizedCaseInsensitiveCompare(rhsAlbum) == .orderedAscending }
            if lhs.discNumber != rhs.discNumber { return lhs.discNumber < rhs.discNumber }
            return lhs.index < rhs.index
        }
    }

    func albums(forArtist name: String) -> [Album] {
        albums.filter { $0.artist.caseInsensitiveCompare(name) == .orderedSame }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func albums(forGenre name: String) -> [Album] {
        albums.filter { ($0.genre ?? "").caseInsensitiveCompare(name) == .orderedSame }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func filteredAlbums(query: String) -> [Album] {
        filterItems(albums, query: query) { [$0.title, $0.artist, $0.genre ?? ""] }
    }

    func filteredTracks(query: String, from source: [Track]) -> [Track] {
        filterItems(source, query: query) { track in
            let album = albumsByID[track.albumID]
            return [track.title, track.artist, album?.title ?? "", album?.genre ?? ""]
        }
    }

    func filteredArtists(query: String) -> [Artist] {
        filterItems(artists, query: query) { [$0.name] }
    }

    func filteredGenres(query: String) -> [Genre] {
        filterItems(genres, query: query) { [$0.name] }
    }

    deinit {
        stopAccessingSecurityScopedResource()
    }

    private func applyScanResult(_ result: LibraryScanResult) {
        albums = result.albums.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        tracks = result.tracks
        artists = result.artists.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        genres = result.genres.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        albumsByID = Dictionary(uniqueKeysWithValues: albums.map { ($0.id, $0) })
        tracksByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        tracksByAlbumID = Dictionary(grouping: tracks, by: \.albumID).mapValues { albumTracks in
            albumTracks.sorted {
                if $0.discNumber != $1.discNumber { return $0.discNumber < $1.discNumber }
                return $0.index < $1.index
            }
        }
    }

    private func stopAccessingSecurityScopedResource() {
        if let url = securityScopedURL {
            url.stopAccessingSecurityScopedResource()
            securityScopedURL = nil
        }
    }

    private func filterItems<T>(
        _ items: [T],
        query: String,
        fields: (T) -> [String]
    ) -> [T] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        let needle = trimmed.lowercased()
        return items.filter { item in
            fields(item).contains { $0.lowercased().contains(needle) }
        }
    }
}
