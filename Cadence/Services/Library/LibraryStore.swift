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

    private var tracksByAlbumID: [UUID: [Track]] = [:]
    private var tracksByID: [UUID: Track] = [:]
    private var albumsByID: [UUID: Album] = [:]
    private var tracksByFilePath: [String: UUID] = [:]
    private var albumSourceFolderPaths: [UUID: String] = [:]

    private(set) var loadedFolderPaths: Set<String> = []
    private var securityScopedURLs: [URL] = []
    private var folderDisplayNames: [String: String] = [:]

    private let scanner = LocalLibraryScanner()
    private let savedFoldersStore = SavedFoldersStore()

    @MainActor
    func loadFolder(_ url: URL) async {
        let path = url.standardizedFileURL.path
        guard !loadedFolderPaths.contains(path) else { return }

        if url.startAccessingSecurityScopedResource() {
            securityScopedURLs.append(url)
        }

        loadedFolderPaths.insert(path)
        folderDisplayNames[path] = url.lastPathComponent

        do {
            try savedFoldersStore.add(url: url)
        } catch {
            logger.error("Failed to save folder bookmark: \(error.localizedDescription)")
        }

        await scanAndMerge(folder: url, sourceFolderPath: path)
    }

    @MainActor
    func restoreSavedFolders() async {
        let resolved = savedFoldersStore.resolveAll()
        for (_, url) in resolved {
            let path = url.standardizedFileURL.path
            guard !loadedFolderPaths.contains(path) else { continue }

            securityScopedURLs.append(url)
            loadedFolderPaths.insert(path)
            folderDisplayNames[path] = url.lastPathComponent
            await scanAndMerge(folder: url, sourceFolderPath: path)
        }
    }

    #if DEBUG
    @MainActor
    func loadPreview(result: LibraryScanResult) {
        clearLibrary()
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
        tracksByFilePath = [:]
        albumSourceFolderPaths = [:]
        loadedFolderPaths = []
        folderDisplayNames = [:]
        stopAccessingAllSecurityScopedResources()
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
            var fields = [track.title, track.artist, album?.title ?? "", album?.genre ?? ""]
            if let label = disambiguationLabel(for: track) {
                fields.append(label)
            }
            return fields
        }
    }

    func filteredArtists(query: String) -> [Artist] {
        filterItems(artists, query: query) { [$0.name] }
    }

    func filteredGenres(query: String) -> [Genre] {
        filterItems(genres, query: query) { [$0.name] }
    }

    func fileNameKey(for track: Track) -> String {
        track.fileURL.deletingPathExtension().lastPathComponent.lowercased()
    }

    func duplicateFileNameKeys() -> Set<String> {
        var counts: [String: Int] = [:]
        for track in tracks {
            let key = fileNameKey(for: track)
            counts[key, default: 0] += 1
        }
        return Set(counts.filter { $0.value > 1 }.map(\.key))
    }

    func disambiguationLabel(for track: Track) -> String? {
        guard duplicateFileNameKeys().contains(fileNameKey(for: track)) else { return nil }

        let albumTitle = album(for: track.albumID)?.title ?? ""
        if !albumTitle.isEmpty && albumTitle != "Unknown Album" {
            return albumTitle
        }
        return folderDisplayName(for: track.fileURL)
    }

    func folderDisplayName(for fileURL: URL) -> String? {
        let path = fileURL.standardizedFileURL.path
        guard let folderPath = loadedFolderPaths
            .filter({ path.hasPrefix($0 + "/") || path == $0 })
            .max(by: { $0.count < $1.count }) else {
            return nil
        }
        return folderDisplayNames[folderPath]
    }

    deinit {
        stopAccessingAllSecurityScopedResources()
    }

    @MainActor
    private func scanAndMerge(folder url: URL, sourceFolderPath: String) async {
        do {
            let result = try await scanner.scan(folder: url)
            mergeScanResult(result, sourceFolderPath: sourceFolderPath)
            logger.info("Merged library from \(sourceFolderPath): \(result.albums.count) albums, \(result.tracks.count) tracks")
        } catch {
            logger.error("Failed to scan folder \(sourceFolderPath): \(error.localizedDescription)")
            loadedFolderPaths.remove(sourceFolderPath)
            folderDisplayNames.removeValue(forKey: sourceFolderPath)
        }
    }

    private func mergeScanResult(_ result: LibraryScanResult, sourceFolderPath: String) {
        var albumIDMap: [UUID: UUID] = [:]

        for newAlbum in result.albums {
            let stableAlbumID = StableIdentity.albumID(
                sourceFolderPath: sourceFolderPath,
                title: newAlbum.title,
                artist: newAlbum.artist
            )

            if let existing = albumsByID[stableAlbumID] {
                albumIDMap[newAlbum.id] = existing.id
                var updated = existing
                updated.year = newAlbum.year ?? updated.year
                updated.genre = newAlbum.genre ?? updated.genre
                updated.coverURL = newAlbum.coverURL ?? updated.coverURL
                updated.folderURL = newAlbum.folderURL ?? updated.folderURL
                replaceAlbum(updated)
            } else {
                albumIDMap[newAlbum.id] = stableAlbumID
                let album = Album(
                    id: stableAlbumID,
                    title: newAlbum.title,
                    artist: newAlbum.artist,
                    year: newAlbum.year,
                    genre: newAlbum.genre,
                    accentColors: newAlbum.accentColors,
                    coverURL: newAlbum.coverURL,
                    folderURL: newAlbum.folderURL
                )
                albums.append(album)
                albumSourceFolderPaths[stableAlbumID] = sourceFolderPath
            }
        }

        for newTrack in result.tracks {
            let path = newTrack.fileURL.standardizedFileURL.path
            let mappedAlbumID = albumIDMap[newTrack.albumID] ?? newTrack.albumID

            if let existingID = tracksByFilePath[path], var existing = tracksByID[existingID] {
                existing.index = newTrack.index
                existing.title = newTrack.title
                existing.artist = newTrack.artist
                existing.albumID = mappedAlbumID
                existing.duration = newTrack.duration
                existing.fileURL = newTrack.fileURL
                existing.discNumber = newTrack.discNumber
                replaceTrack(existing)
            } else {
                let stableTrackID = StableIdentity.trackID(for: newTrack.fileURL)
                let track = Track(
                    id: stableTrackID,
                    index: newTrack.index,
                    title: newTrack.title,
                    artist: newTrack.artist,
                    albumID: mappedAlbumID,
                    duration: newTrack.duration,
                    fileURL: newTrack.fileURL,
                    discNumber: newTrack.discNumber
                )
                tracks.append(track)
                tracksByFilePath[path] = track.id
            }
        }

        rebuildDerivedData()
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
        tracksByFilePath = Dictionary(uniqueKeysWithValues: tracks.map {
            ($0.fileURL.standardizedFileURL.path, $0.id)
        })
    }

    private func replaceAlbum(_ album: Album) {
        if let index = albums.firstIndex(where: { $0.id == album.id }) {
            albums[index] = album
        }
        albumsByID[album.id] = album
    }

    private func replaceTrack(_ track: Track) {
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            tracks[index] = track
        }
        tracksByID[track.id] = track
    }

    private func rebuildDerivedData() {
        albums.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        albumsByID = Dictionary(uniqueKeysWithValues: albums.map { ($0.id, $0) })
        tracksByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        tracksByFilePath = Dictionary(uniqueKeysWithValues: tracks.map {
            ($0.fileURL.standardizedFileURL.path, $0.id)
        })
        tracksByAlbumID = Dictionary(grouping: tracks, by: \.albumID).mapValues { albumTracks in
            albumTracks.sorted {
                if $0.discNumber != $1.discNumber { return $0.discNumber < $1.discNumber }
                return $0.index < $1.index
            }
        }

        var artistAlbumMap: [String: Set<UUID>] = [:]
        var genreAlbumMap: [String: Set<UUID>] = [:]

        for album in albums {
            artistAlbumMap[album.artist, default: []].insert(album.id)
            if let genre = album.genre {
                genreAlbumMap[genre, default: []].insert(album.id)
            }
        }

        artists = artistAlbumMap
            .map { Artist(name: $0.key, albumIDs: Array($0.value)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        genres = genreAlbumMap
            .map { Genre(name: $0.key, albumIDs: Array($0.value)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func stopAccessingAllSecurityScopedResources() {
        for url in securityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        securityScopedURLs = []
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
