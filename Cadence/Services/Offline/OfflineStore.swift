import Foundation
import os.log

private let logger = Logger(subsystem: "dev.personal.cadence", category: "Offline")

enum OfflineOrigin: String, Codable, Equatable {
    case favorite
    case manual
}

struct OfflineEntry: Codable, Equatable {
    let trackID: UUID
    let jellyfinItemID: String?
    var fileName: String
    var byteSize: Int64
    var origin: OfflineOrigin
    var downloadedAt: Date
}

enum OfflineState: Equatable {
    case none
    case queued
    case downloading(Double)
    case ready
    case failed
}

@Observable
@MainActor
final class OfflineStore {
    private(set) var entries: [UUID: OfflineEntry] = [:]
    private(set) var activeStates: [UUID: OfflineState] = [:]
    private(set) var batchTotal: Int = 0
    private(set) var batchCompleted: Int = 0
    private(set) var isBatchDownloading = false

    private let rootDirectory: URL
    private let queue: OfflineDownloadQueue
    private var batchCancelRequested = false
    private var pendingManualPromotion: Set<UUID> = []

    var totalBytes: Int64 {
        entries.values.reduce(0) { $0 + $1.byteSize }
    }

    var trackCount: Int {
        entries.count
    }

    var storageURL: URL {
        rootDirectory.appendingPathComponent("offline.json")
    }

    init(rootDirectory: URL? = nil) {
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            self.rootDirectory = appSupport.appendingPathComponent("Cadence/offline", isDirectory: true)
        }
        self.queue = OfflineDownloadQueue(directory: self.rootDirectory)
        try? FileManager.default.createDirectory(at: self.rootDirectory, withIntermediateDirectories: true)
        load()
        pruneMissingFiles()
    }

    func localURL(for trackID: UUID) -> URL? {
        guard let entry = entries[trackID] else { return nil }
        let url = rootDirectory.appendingPathComponent(entry.fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func state(for trackID: UUID) -> OfflineState {
        if let active = activeStates[trackID] {
            return active
        }
        if entries[trackID] != nil {
            return .ready
        }
        return .none
    }

    func isReady(_ trackID: UUID) -> Bool {
        localURL(for: trackID) != nil
    }

    func offlineTracks(from library: LibraryStore) -> [Track] {
        entries.keys.compactMap { library.track(for: $0) }
    }

    func download(track: Track, client: JellyfinClient, origin: OfflineOrigin) {
        guard !track.fileURL.isFileURL else { return }

        if entries[track.id] != nil {
            if origin == .manual {
                promoteToManual(trackID: track.id)
            }
            return
        }

        switch state(for: track.id) {
        case .queued, .downloading:
            if origin == .manual {
                pendingManualPromotion.insert(track.id)
            }
            return
        default:
            break
        }

        if origin == .manual {
            pendingManualPromotion.insert(track.id)
        }

        activeStates[track.id] = .queued

        Task {
            await enqueueDownload(track: track, client: client, origin: origin, itemID: JellyfinIdentity.itemID(from: track.fileURL))
        }
    }

    func downloadAll(tracks: [Track], client: JellyfinClient, origin: OfflineOrigin) {
        if origin == .manual {
            for track in tracks where entries[track.id] != nil {
                promoteToManual(trackID: track.id)
            }
        }

        let pending = tracks.filter { track in
            !track.fileURL.isFileURL
                && entries[track.id] == nil
                && activeStates[track.id] == nil
        }
        guard !pending.isEmpty else { return }

        batchCancelRequested = false
        isBatchDownloading = true
        batchTotal = pending.count
        batchCompleted = 0

        for track in pending {
            activeStates[track.id] = .queued
        }

        Task {
            await withTaskGroup(of: Void.self) { group in
                for track in pending {
                    group.addTask { @MainActor in
                        guard !self.batchCancelRequested else { return }
                        await self.enqueueDownload(
                            track: track,
                            client: client,
                            origin: origin,
                            itemID: JellyfinIdentity.itemID(from: track.fileURL)
                        )
                        self.batchCompleted += 1
                    }
                }
            }
            self.isBatchDownloading = false
            self.batchTotal = 0
            self.batchCompleted = 0
            self.batchCancelRequested = false
        }
    }

    func cancelBatchDownload() {
        batchCancelRequested = true
        let ids = Array(activeStates.keys)
        for id in ids {
            cancelDownload(trackID: id)
        }
    }

    func cancelDownload(trackID: UUID) {
        Task {
            await queue.cancel(trackID: trackID)
        }
        activeStates[trackID] = nil
    }

    func remove(trackID: UUID) {
        cancelDownload(trackID: trackID)
        if let entry = entries.removeValue(forKey: trackID) {
            let url = rootDirectory.appendingPathComponent(entry.fileName)
            try? FileManager.default.removeItem(at: url)
            save()
        }
        activeStates[trackID] = nil
    }

    func removeIfFavoriteOrigin(trackID: UUID) {
        guard let entry = entries[trackID], entry.origin == .favorite else { return }
        remove(trackID: trackID)
    }

    func promoteToManual(trackID: UUID) {
        guard var entry = entries[trackID], entry.origin != .manual else { return }
        entry.origin = .manual
        entries[trackID] = entry
        save()
    }

    func clearAll() {
        cancelBatchDownload()
        for entry in entries.values {
            let url = rootDirectory.appendingPathComponent(entry.fileName)
            try? FileManager.default.removeItem(at: url)
        }
        entries.removeAll()
        activeStates.removeAll()
        save()
    }

    func pruneMissingFiles() {
        var changed = false
        for (id, entry) in entries {
            let url = rootDirectory.appendingPathComponent(entry.fileName)
            if !FileManager.default.fileExists(atPath: url.path) {
                entries.removeValue(forKey: id)
                changed = true
            }
        }
        if changed {
            save()
        }
    }

    /// Inserts a completed offline entry and writes a placeholder file. Used by unit tests.
    func seedCompletedEntry(_ entry: OfflineEntry, fileContents: Data = Data([0x00])) throws {
        let url = rootDirectory.appendingPathComponent(entry.fileName)
        try fileContents.write(to: url, options: .atomic)
        entries[entry.trackID] = entry
        activeStates[entry.trackID] = nil
        save()
    }

    // MARK: - Private

    private func enqueueDownload(
        track: Track,
        client: JellyfinClient,
        origin: OfflineOrigin,
        itemID: String?
    ) async {
        activeStates[track.id] = .queued

        do {
            let result = try await queue.download(
                trackID: track.id,
                jellyfinItemID: itemID,
                client: client
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.activeStates[track.id] = .downloading(progress)
                }
            }

            let resolvedOrigin: OfflineOrigin =
                pendingManualPromotion.contains(track.id) ? .manual : origin
            pendingManualPromotion.remove(track.id)

            let entry = OfflineEntry(
                trackID: track.id,
                jellyfinItemID: itemID,
                fileName: result.fileName,
                byteSize: result.byteSize,
                origin: resolvedOrigin,
                downloadedAt: Date()
            )
            entries[track.id] = entry
            activeStates[track.id] = nil
            save()

            await AudioCache.shared.removeCachedFile(trackID: track.id)
            logger.info("Offline ready: '\(track.title)' (\(result.byteSize) bytes)")
        } catch is CancellationError {
            pendingManualPromotion.remove(track.id)
            activeStates[track.id] = nil
        } catch OfflineDownloadError.cancelled {
            pendingManualPromotion.remove(track.id)
            activeStates[track.id] = nil
        } catch {
            logger.error("Offline download failed: \(error.localizedDescription)")
            activeStates[track.id] = .failed
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([OfflineEntry].self, from: data) else {
            return
        }
        entries = Dictionary(uniqueKeysWithValues: decoded.map { ($0.trackID, $0) })
    }

    private func save() {
        let list = Array(entries.values)
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }
}
