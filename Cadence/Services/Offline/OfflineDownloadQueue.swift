import Foundation
import os.log

private let logger = Logger(subsystem: "dev.personal.cadence", category: "OfflineDownload")

struct OfflineDownloadResult: Sendable {
    let fileName: String
    let byteSize: Int64
    let fileURL: URL
}

enum OfflineDownloadError: LocalizedError {
    case missingItemID
    case invalidURL
    case httpError(Int)
    case cancelled
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .missingItemID: return "Нет Jellyfin item ID"
        case .invalidURL: return "Неверный URL загрузки"
        case .httpError(let code): return "Ошибка загрузки: HTTP \(code)"
        case .cancelled: return "Загрузка отменена"
        case .writeFailed: return "Не удалось записать файл"
        }
    }
}

actor OfflineDownloadQueue {
    private let directory: URL
    private let maxConcurrent = 2

    private var activeTasks: [UUID: Task<OfflineDownloadResult, Error>] = [:]
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var runningCount = 0

    init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func download(
        trackID: UUID,
        jellyfinItemID: String?,
        client: JellyfinClient,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> OfflineDownloadResult {
        if let existing = activeTasks[trackID] {
            return try await existing.value
        }

        let task = Task<OfflineDownloadResult, Error> {
            try await self.waitForSlot()
            defer { Task { await self.releaseSlot() } }

            guard let itemID = jellyfinItemID else {
                throw OfflineDownloadError.missingItemID
            }

            return try await self.performDownload(
                trackID: trackID,
                itemID: itemID,
                client: client,
                onProgress: onProgress
            )
        }

        activeTasks[trackID] = task
        defer { activeTasks[trackID] = nil }

        do {
            return try await task.value
        } catch is CancellationError {
            throw OfflineDownloadError.cancelled
        }
    }

    func cancel(trackID: UUID) {
        activeTasks[trackID]?.cancel()
        activeTasks[trackID] = nil
    }

    // MARK: - Concurrency

    private func waitForSlot() async throws {
        while runningCount >= maxConcurrent {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
            try Task.checkCancellation()
        }
        runningCount += 1
    }

    private func releaseSlot() async {
        runningCount = max(0, runningCount - 1)
        if !waiters.isEmpty {
            let next = waiters.removeFirst()
            next.resume()
        }
    }

    // MARK: - Download

    private func performDownload(
        trackID: UUID,
        itemID: String,
        client: JellyfinClient,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> OfflineDownloadResult {
        try Task.checkCancellation()

        guard let primary = client.originalFileURL(itemID: itemID) else {
            throw OfflineDownloadError.invalidURL
        }

        do {
            return try await downloadURL(primary, trackID: trackID, onProgress: onProgress)
        } catch OfflineDownloadError.httpError(let code) where code == 401 || code == 403 {
            guard let fallback = client.staticStreamURL(itemID: itemID) else {
                throw OfflineDownloadError.invalidURL
            }
            logger.info("Download fallback to static stream for \(itemID)")
            return try await downloadURL(fallback, trackID: trackID, onProgress: onProgress)
        }
    }

    private func downloadURL(
        _ remoteURL: URL,
        trackID: UUID,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> OfflineDownloadResult {
        try Task.checkCancellation()

        let partialURL = directory
            .appendingPathComponent(trackID.uuidString)
            .appendingPathExtension("part")
        try? FileManager.default.removeItem(at: partialURL)

        let downloaded = try await OfflineFileDownloader.download(
            from: remoteURL,
            to: partialURL,
            onProgress: onProgress
        )

        try Task.checkCancellation()

        let ext = downloaded.fileExtension
        let finalURL = directory
            .appendingPathComponent(trackID.uuidString)
            .appendingPathExtension(ext)

        try? FileManager.default.removeItem(at: finalURL)
        try FileManager.default.moveItem(at: partialURL, to: finalURL)

        onProgress(1.0)

        let size = (try? FileManager.default.attributesOfItem(atPath: finalURL.path)[.size] as? Int64) ?? downloaded.byteSize

        return OfflineDownloadResult(
            fileName: finalURL.lastPathComponent,
            byteSize: size,
            fileURL: finalURL
        )
    }
}

// MARK: - URLSession download helper

private final class OfflineFileDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destinationURL: URL
    private let onProgress: @Sendable (Double) -> Void
    private var continuation: CheckedContinuation<(fileExtension: String, byteSize: Int64), Error>?
    private var resolvedExtension = "mp3"
    private var session: URLSession!
    private var task: URLSessionDownloadTask?

    private init(destinationURL: URL, onProgress: @escaping @Sendable (Double) -> Void) {
        self.destinationURL = destinationURL
        self.onProgress = onProgress
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 60 * 60
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    static func download(
        from remoteURL: URL,
        to destinationURL: URL,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> (fileExtension: String, byteSize: Int64) {
        let downloader = OfflineFileDownloader(destinationURL: destinationURL, onProgress: onProgress)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                downloader.continuation = continuation
                let task = downloader.session.downloadTask(with: remoteURL)
                downloader.task = task
                task.resume()
            }
        } onCancel: {
            downloader.task?.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if totalBytesExpectedToWrite > 0 {
            onProgress(min(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 0.99))
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            if let http = downloadTask.response as? HTTPURLResponse {
                guard (200...299).contains(http.statusCode) else {
                    continuation?.resume(throwing: OfflineDownloadError.httpError(http.statusCode))
                    continuation = nil
                    return
                }
                resolvedExtension = Self.fileExtension(from: http) ?? "mp3"
            }

            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.copyItem(at: location, to: destinationURL)
            let size = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber)?
                .int64Value ?? 0
            continuation?.resume(returning: (resolvedExtension, size))
            continuation = nil
        } catch {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        if (error as NSError).code == NSURLErrorCancelled {
            continuation?.resume(throwing: CancellationError())
        } else {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        JellyfinURLSessionFactory.handleServerTrustChallenge(challenge, completionHandler: completionHandler)
    }

    private static func fileExtension(from response: HTTPURLResponse) -> String? {
        if let contentType = response.value(forHTTPHeaderField: "Content-Type"),
           let ext = AudioEngineService.ext(forContentType: contentType) {
            return ext
        }
        if let disposition = response.value(forHTTPHeaderField: "Content-Disposition"),
           let name = suggestedFilename(from: disposition),
           let ext = name.split(separator: ".").last.map(String.init),
           !ext.isEmpty,
           ext.count <= 5 {
            return ext.lowercased()
        }
        if let pathExt = response.url?.pathExtension, !pathExt.isEmpty {
            return pathExt.lowercased()
        }
        return nil
    }

    private static func suggestedFilename(from disposition: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"filename\*?=(?:UTF-8''|")?([^";]+)"#,
            options: .caseInsensitive
        ) else { return nil }
        let range = NSRange(disposition.startIndex..<disposition.endIndex, in: disposition)
        guard let match = regex.firstMatch(in: disposition, range: range),
              let valueRange = Range(match.range(at: 1), in: disposition) else {
            return nil
        }
        var value = String(disposition[valueRange]).trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
        if value.lowercased().hasPrefix("utf-8''") {
            value = String(value.dropFirst(7))
        }
        return value.removingPercentEncoding ?? value
    }
}
