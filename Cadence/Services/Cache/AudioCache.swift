import Foundation
import os.log

private let logger = Logger(subsystem: "dev.personal.cadence", category: "AudioCache")

actor AudioCache {
    static let shared = AudioCache()

    private var maxCacheBytes: Int64 = 2 * 1_073_741_824
    private var inFlightDownloads: [UUID: Task<URL, Error>] = [:]

    private init() {}

    func setMaxCacheBytes(_ bytes: Int64) {
        maxCacheBytes = max(bytes, 0)
    }

    func localURL(for remoteURL: URL, trackID: UUID) async throws -> URL {
        if let cached = Self.cachedFileURL(trackID: trackID) {
            Self.touch(cached)
            return cached
        }

        if let existingTask = inFlightDownloads[trackID] {
            return try await existingTask.value
        }

        let task = Task<URL, Error> {
            try await Self.download(remoteURL: remoteURL, trackID: trackID)
        }
        inFlightDownloads[trackID] = task

        defer { inFlightDownloads[trackID] = nil }

        let localURL = try await task.value
        enforceCacheLimit()
        return localURL
    }

    func diskUsageBytes() -> Int64 {
        Self.directorySize(at: Self.audioDirectory)
    }

    func clearAll() {
        try? FileManager.default.removeItem(at: Self.audioDirectory)
    }

    nonisolated static func totalDiskUsageBytes() -> Int64 {
        directorySize(at: audioDirectory)
    }

    private static func download(remoteURL: URL, trackID: UUID) async throws -> URL {
        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 60

        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        let ext = (response as? HTTPURLResponse)
            .flatMap { $0.value(forHTTPHeaderField: "Content-Type") }
            .flatMap { AudioEngineService.ext(forContentType: $0) }
            ?? "mp3"

        let directory = audioDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let destinationURL = directory
            .appendingPathComponent(trackID.uuidString)
            .appendingPathExtension(ext)

        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        touch(destinationURL)
        return destinationURL
    }

    private func enforceCacheLimit() {
        guard maxCacheBytes > 0 else { return }

        let directory = Self.audioDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentAccessDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var entries: [(url: URL, accessDate: Date, size: Int64)] = []
        var totalSize: Int64 = 0

        for fileURL in files {
            let values = try? fileURL.resourceValues(forKeys: [.contentAccessDateKey, .fileSizeKey])
            let size = Int64(values?.fileSize ?? 0)
            let accessDate = values?.contentAccessDate ?? .distantPast
            entries.append((fileURL, accessDate, size))
            totalSize += size
        }

        guard totalSize > maxCacheBytes else { return }

        for entry in entries.sorted(by: { $0.accessDate < $1.accessDate }) {
            guard totalSize > maxCacheBytes else { break }
            do {
                try FileManager.default.removeItem(at: entry.url)
                totalSize -= entry.size
            } catch {
                logger.debug("Failed to evict cache file: \(error.localizedDescription)")
            }
        }
    }

    nonisolated static func cachedFileURL(trackID: UUID) -> URL? {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: audioDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let prefix = trackID.uuidString
        return files.first { $0.deletingPathExtension().lastPathComponent == prefix }
    }

    nonisolated static var audioDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("dev.personal.cadence/audio", isDirectory: true)
    }

    nonisolated static func touch(_ url: URL) {
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
    }

    nonisolated static func directorySize(at url: URL) -> Int64 {
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
