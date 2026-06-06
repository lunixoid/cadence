import AVFoundation
import Foundation
import SwiftUI

struct LocalLibraryScanner {
    private static let audioExtensions: Set<String> = [
        "flac", "alac", "mp3", "aac", "m4a", "ogg", "wav", "aiff", "aif", "opus",
    ]

    private static let coverFileNames = [
        "cover.jpg", "cover.png", "folder.jpg", "folder.png",
        "front.jpg", "front.png", "artwork.jpg", "artwork.png",
    ]

    func scan(folder rootURL: URL) async throws -> LibraryScanResult {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return LibraryScanResult(albums: [], tracks: [], artists: [])
        }

        var scannedTracks: [ScannedTrack] = []

        for case let fileURL as URL in enumerator {
            guard isAudioFile(fileURL) else { continue }
            if let scanned = await scanFile(at: fileURL) {
                scannedTracks.append(scanned)
            }
        }

        return buildLibrary(from: scannedTracks)
    }

    private func isAudioFile(_ url: URL) -> Bool {
        Self.audioExtensions.contains(url.pathExtension.lowercased())
    }

    private func scanFile(at url: URL) async -> ScannedTrack? {
        let asset = AVURLAsset(url: url)
        let metadata = await loadMetadata(from: asset)

        let title = metadata.title ?? url.deletingPathExtension().lastPathComponent
        let artist = metadata.artist ?? "Unknown Artist"
        let albumTitle = metadata.album ?? "Unknown Album"
        let albumArtist = metadata.albumArtist ?? artist

        let duration: TimeInterval
        if let loadedDuration = try? await asset.load(.duration),
           loadedDuration.isNumeric {
            duration = loadedDuration.seconds
        } else {
            duration = 0
        }

        return ScannedTrack(
            fileURL: url,
            title: title,
            artist: artist,
            albumTitle: albumTitle,
            albumArtist: albumArtist,
            trackNumber: metadata.trackNumber ?? 0,
            discNumber: metadata.discNumber ?? 1,
            year: metadata.year,
            duration: duration,
            embeddedCoverData: metadata.artworkData
        )
    }

    private func buildLibrary(from scanned: [ScannedTrack]) -> LibraryScanResult {
        struct AlbumKey: Hashable {
            let title: String
            let artist: String
        }

        var albumGroups: [AlbumKey: [ScannedTrack]] = [:]
        for track in scanned {
            let key = AlbumKey(title: track.albumTitle, artist: track.albumArtist)
            albumGroups[key, default: []].append(track)
        }

        var albums: [Album] = []
        var tracks: [Track] = []
        var artistAlbumMap: [String: Set<UUID>] = [:]

        for (key, groupTracks) in albumGroups {
            let albumID = UUID()
            let sortedGroup = groupTracks.sorted {
                if $0.discNumber != $1.discNumber { return $0.discNumber < $1.discNumber }
                let lhsIndex = $0.trackNumber > 0 ? $0.trackNumber : Int.max
                let rhsIndex = $1.trackNumber > 0 ? $1.trackNumber : Int.max
                if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }

            let folderURL = commonFolder(for: sortedGroup.map(\.fileURL))
            let coverURL = resolveCoverURL(for: sortedGroup, folderURL: folderURL)
            let year = sortedGroup.compactMap(\.year).first

            let album = Album(
                id: albumID,
                title: key.title,
                artist: key.artist,
                year: year,
                accentColors: accentColors(for: albumID),
                coverURL: coverURL,
                folderURL: folderURL
            )
            albums.append(album)

            artistAlbumMap[key.artist, default: []].insert(albumID)

            for (offset, scannedTrack) in sortedGroup.enumerated() {
                let index = scannedTrack.trackNumber > 0 ? scannedTrack.trackNumber : offset + 1
                tracks.append(
                    Track(
                        index: index,
                        title: scannedTrack.title,
                        artist: scannedTrack.artist,
                        albumID: albumID,
                        duration: scannedTrack.duration,
                        fileURL: scannedTrack.fileURL,
                        discNumber: scannedTrack.discNumber
                    )
                )
            }
        }

        let artists = artistAlbumMap.map { Artist(name: $0.key, albumIDs: Array($0.value)) }

        return LibraryScanResult(albums: albums, tracks: tracks, artists: artists)
    }

    private func commonFolder(for urls: [URL]) -> URL? {
        guard let first = urls.first else { return nil }
        var commonPath = first.deletingLastPathComponent().path
        for url in urls.dropFirst() {
            let path = url.deletingLastPathComponent().path
            while !path.hasPrefix(commonPath) && !commonPath.isEmpty {
                commonPath = (commonPath as NSString).deletingLastPathComponent
            }
        }
        return commonPath.isEmpty ? first.deletingLastPathComponent() : URL(fileURLWithPath: commonPath)
    }

    private func resolveCoverURL(for tracks: [ScannedTrack], folderURL: URL?) -> URL? {
        if let embedded = tracks.compactMap(\.embeddedCoverData).first {
            return writeTemporaryCover(data: embedded)
        }

        if let folderURL {
            for name in Self.coverFileNames {
                let candidate = folderURL.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        for track in tracks {
            let parent = track.fileURL.deletingLastPathComponent()
            for name in Self.coverFileNames {
                let candidate = parent.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        return nil
    }

    private func writeTemporaryCover(data: Data) -> URL? {
        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("CadenceCovers", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let fileName = data.hashValue.description + ".jpg"
        let url = cacheDir.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? data.write(to: url)
        }
        return url
    }

    private func accentColors(for albumID: UUID) -> [Color] {
        let hash = albumID.uuidString.hashValue
        let hue1 = Double(abs(hash % 360)) / 360.0
        let hue2 = Double(abs((hash / 360) % 360)) / 360.0
        return [
            Color(hue: hue1, saturation: 0.45, brightness: 0.35),
            Color(hue: hue2, saturation: 0.55, brightness: 0.55),
            Color(hue: hue1, saturation: 0.25, brightness: 0.75),
        ]
    }

    private struct ScannedTrack {
        var fileURL: URL
        var title: String
        var artist: String
        var albumTitle: String
        var albumArtist: String
        var trackNumber: Int
        var discNumber: Int
        var year: Int?
        var duration: TimeInterval
        var embeddedCoverData: Data?
    }

    private struct ParsedMetadata {
        var title: String?
        var artist: String?
        var album: String?
        var albumArtist: String?
        var trackNumber: Int?
        var discNumber: Int?
        var year: Int?
        var artworkData: Data?
    }

    private func loadMetadata(from asset: AVURLAsset) async -> ParsedMetadata {
        var result = ParsedMetadata()

        guard let items = try? await asset.load(.commonMetadata) else { return result }

        for item in items {
            guard let key = item.commonKey else { continue }
            switch key {
            case .commonKeyTitle:
                result.title = stringValue(from: item)
            case .commonKeyArtist:
                result.artist = stringValue(from: item)
            case .commonKeyAlbumName:
                result.album = stringValue(from: item)
            case .commonKeyAuthor:
                if result.albumArtist == nil {
                    result.albumArtist = stringValue(from: item)
                }
            case .commonKeyType where item.value is NSNumber:
                if result.trackNumber == nil, let number = item.numberValue?.intValue {
                    result.trackNumber = number
                }
            case .commonKeyCreationDate:
                if let dateString = stringValue(from: item), let year = Int(dateString.prefix(4)) {
                    result.year = year
                }
            case .commonKeyArtwork:
                if let data = await artworkData(from: item) {
                    result.artworkData = data
                }
            default:
                break
            }
        }

        if let formatItems = try? await asset.load(.metadata) {
            for item in formatItems {
                guard let identifier = item.identifier else { continue }
                let idString = identifier.rawValue.lowercased()
                if idString.contains("albumartist") || idString.contains("band") {
                    result.albumArtist = stringValue(from: item) ?? result.albumArtist
                } else if idString.contains("tracknumber") || idString.contains("track") {
                    result.trackNumber = parseTrackNumber(stringValue(from: item)) ?? result.trackNumber
                } else if idString.contains("discnumber") || idString.contains("disc") {
                    result.discNumber = parseTrackNumber(stringValue(from: item)) ?? result.discNumber
                } else if idString.contains("date") || idString.contains("year") {
                    if let value = stringValue(from: item), let year = Int(value.prefix(4)) {
                        result.year = year
                    }
                }
            }
        }

        return result
    }

    private func stringValue(from item: AVMetadataItem) -> String? {
        if let string = item.stringValue { return string }
        if let number = item.numberValue { return number.stringValue }
        return nil
    }

    private func artworkData(from item: AVMetadataItem) async -> Data? {
        if let data = item.dataValue { return data }
        if let value = try? await item.load(.value) as? Data { return value }
        return nil
    }

    private func parseTrackNumber(_ value: String?) -> Int? {
        guard let value else { return nil }
        let components = value.split(separator: "/")
        return Int(components.first ?? "")
    }
}
