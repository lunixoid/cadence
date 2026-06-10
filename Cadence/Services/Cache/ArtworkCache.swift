import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: "dev.personal.cadence", category: "ArtworkCache")

actor ArtworkCache {
    static let shared = ArtworkCache()

    private let memoryCache = NSCache<NSString, NSImage>()
    private let session: URLSession

    private init() {
        memoryCache.countLimit = 200
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
    }

    // MARK: - Public API

    func image(for url: URL, itemID: String? = nil, maxWidth: Int = 300) async -> NSImage? {
        if url.isFileURL {
            return NSImage(contentsOf: url)
        }

        let resolvedItemID = itemID ?? Self.parseItemID(from: url)
        let cacheKey = Self.cacheKey(itemID: resolvedItemID, url: url, maxWidth: maxWidth)

        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            return cached
        }

        if let itemID = resolvedItemID,
           let fileURL = Self.cachedFileURL(itemID: itemID, maxWidth: maxWidth),
           let image = NSImage(contentsOf: fileURL) {
            memoryCache.setObject(image, forKey: cacheKey as NSString)
            return image
        }

        do {
            let (data, _) = try await session.data(from: url)
            guard let image = NSImage(data: data) else { return nil }

            if let itemID = resolvedItemID {
                Self.writeToDisk(data: data, itemID: itemID, maxWidth: maxWidth)
            }

            memoryCache.setObject(image, forKey: cacheKey as NSString)
            return image
        } catch {
            logger.debug("Artwork download failed: \(error.localizedDescription)")
            return nil
        }
    }

    func prefetch(coverURLs: [URL], limit: Int = 30) async {
        for url in coverURLs.prefix(limit) where !url.isFileURL {
            _ = await image(for: url, maxWidth: Self.parseMaxWidth(from: url) ?? 300)
        }
    }

    func diskUsageBytes() -> Int64 {
        Self.directorySize(at: Self.artworkDirectory)
    }

    func clearAll() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: Self.artworkDirectory)
    }

    // MARK: - Static helpers

    nonisolated static func cachedFileURL(itemID: String, maxWidth: Int) -> URL? {
        let url = artworkDirectory.appendingPathComponent(fileName(itemID: itemID, maxWidth: maxWidth))
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    nonisolated static func parseItemID(from url: URL) -> String? {
        let path = url.path
        guard let range = path.range(of: "/Items/") else { return nil }
        let afterItems = path[range.upperBound...]
        guard let slash = afterItems.firstIndex(of: "/") else { return nil }
        let itemID = String(afterItems[..<slash])
        return itemID.isEmpty ? nil : itemID
    }

    nonisolated static func parseMaxWidth(from url: URL) -> Int? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let maxHeight = components.queryItems?.first(where: { $0.name == "maxHeight" })?.value
        else { return nil }
        return Int(maxHeight)
    }

    nonisolated static func totalDiskUsageBytes() -> Int64 {
        directorySize(at: artworkDirectory)
            + JellyfinLibraryCache.diskUsageBytes()
            + AudioCache.totalDiskUsageBytes()
    }

    // MARK: - Private

    private nonisolated static var artworkDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("Cadence/artwork", isDirectory: true)
    }

    private nonisolated static func fileName(itemID: String, maxWidth: Int) -> String {
        "\(itemID)-\(maxWidth).jpg"
    }

    private nonisolated static func cacheKey(itemID: String?, url: URL, maxWidth: Int) -> String {
        if let itemID {
            return "\(itemID)-\(maxWidth)"
        }
        return url.absoluteString
    }

    private nonisolated static func writeToDisk(data: Data, itemID: String, maxWidth: Int) {
        let directory = artworkDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(fileName(itemID: itemID, maxWidth: maxWidth))
        try? data.write(to: fileURL, options: .atomic)
    }

    private nonisolated static func directorySize(at url: URL) -> Int64 {
        guard FileManager.default.fileExists(atPath: url.path),
              let enumerator = FileManager.default.enumerator(
                  at: url,
                  includingPropertiesForKeys: [.fileSizeKey],
                  options: [.skipsHiddenFiles]
              )
        else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
        return total
    }
}
