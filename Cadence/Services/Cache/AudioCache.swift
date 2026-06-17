import Foundation
import os.log

private let logger = Logger(subsystem: "dev.personal.cadence", category: "AudioCache")

actor AudioCache {
    static let shared = AudioCache()

    private var maxCacheBytes: Int64 = 2 * 1_073_741_824
    private var activeSessions: [UUID: ProgressiveDownloadSession] = [:]

    private init() {}

    func setMaxCacheBytes(_ bytes: Int64) {
        maxCacheBytes = max(bytes, 0)
    }

    func hasCachedFile(trackID: UUID) -> Bool {
        Self.cachedFileURL(trackID: trackID) != nil
    }

    func localURL(for remoteURL: URL, trackID: UUID) async throws -> URL {
        if let cached = Self.cachedFileURL(trackID: trackID) {
            Self.touch(cached)
            return cached
        }

        let session = try await downloadSession(for: remoteURL, trackID: trackID)
        let url = try await session.waitForCompletion()
        enforceCacheLimit()
        return url
    }

    func progressiveAsset(for remoteURL: URL, trackID: UUID) async throws -> ProgressiveAudioAsset {
        let session = try await downloadSession(for: remoteURL, trackID: trackID)
        return ProgressiveAudioAsset(session: session)
    }

    func existingSession(for trackID: UUID) -> ProgressiveDownloadSession? {
        activeSessions[trackID]
    }

    func diskUsageBytes() -> Int64 {
        Self.directorySize(at: Self.audioDirectory)
    }

    func clearAll() {
        for session in activeSessions.values {
            Task { await session.cancelAndDeletePartial() }
        }
        activeSessions.removeAll()
        try? FileManager.default.removeItem(at: Self.audioDirectory)
    }

    nonisolated static func totalDiskUsageBytes() -> Int64 {
        directorySize(at: audioDirectory)
    }

    private func downloadSession(for remoteURL: URL, trackID: UUID) async throws -> ProgressiveDownloadSession {
        if let existing = activeSessions[trackID] {
            return existing
        }

        let ext = "partial"
        let partialURL = Self.audioDirectory
            .appendingPathComponent("\(trackID.uuidString).partial")
            .appendingPathExtension(ext)

        let session = try ProgressiveDownloadSession(
            trackID: trackID,
            remoteURL: remoteURL,
            partialURL: partialURL
        )
        activeSessions[trackID] = session
        await session.start()
        return session
    }

    func sessionDidComplete(trackID: UUID) {
        activeSessions[trackID] = nil
        enforceCacheLimit()
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
            let name = fileURL.deletingPathExtension().lastPathComponent
            if name.hasSuffix(".partial") { continue }

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
        return files.first { url in
            let name = url.deletingPathExtension().lastPathComponent
            return name == prefix && !name.hasSuffix(".partial")
        }
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
