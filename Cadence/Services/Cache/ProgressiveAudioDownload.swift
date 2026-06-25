import AVFoundation
import Foundation
import os.log

private let logger = Logger(subsystem: "dev.personal.cadence", category: "ProgressiveDownload")

struct ProgressiveDownloadProgress: Sendable {
    let bytesDownloaded: Int64
    let expectedBytes: Int64?
    let isComplete: Bool
}

enum ProgressiveDownloadError: LocalizedError {
    case cancelled
    case invalidResponse
    case exhaustedRetries
    case readBeyondDownloadedBoundary

    var errorDescription: String? {
        switch self {
        case .cancelled: "Download cancelled"
        case .invalidResponse: "Invalid server response"
        case .exhaustedRetries: "Download failed after retries"
        case .readBeyondDownloadedBoundary: "Playback reached undownloaded audio"
        }
    }
}

enum ProgressivePlayback {
    static let initialBufferBytes: Int64 = 4_000_000
    static let safetyMarginFrames: AVAudioFramePosition = 88_200
    static let continueWaitByteIncrement: Int64 = 2 * 1024 * 1024
}

actor ProgressiveDownloadSession {
    let trackID: UUID
    let remoteURL: URL
    let partialURL: URL

    private var bytesDownloaded: Int64 = 0
    private var expectedBytes: Int64?
    private(set) var isComplete = false
    private(set) var finalURL: URL?
    private var failure: Error?
    private var isCancelled = false
    private var retryCount = 0

    private var progressContinuations: [UUID: AsyncStream<ProgressiveDownloadProgress>.Continuation] = [:]
    private var byteWaiters: [(threshold: Int64, continuation: CheckedContinuation<Void, Error>)] = []
    private var completionWaiters: [CheckedContinuation<URL, Error>] = []

    private var worker: ProgressiveDownloadWorker?
    private var fileHandle: FileHandle?
    private var downloadedFileExtension = "mp3"

    init(trackID: UUID, remoteURL: URL, partialURL: URL) throws {
        self.trackID = trackID
        self.remoteURL = remoteURL
        self.partialURL = partialURL

        let directory = partialURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: partialURL)
        FileManager.default.createFile(atPath: partialURL.path, contents: nil)
        self.fileHandle = try FileHandle(forWritingTo: partialURL)
    }

    func start() {
        guard !isComplete, worker == nil else { return }
        let worker = ProgressiveDownloadWorker(
            remoteURL: remoteURL,
            onResponse: { [weak self] expectedBytes, fileExtension in
                guard let self else { return }
                Task { await self.handleResponse(expectedBytes: expectedBytes, fileExtension: fileExtension) }
            },
            onData: { [weak self] data in
                guard let self else { return }
                Task {
                    do {
                        try await self.appendData(data)
                    } catch {
                        await self.fail(with: error)
                    }
                }
            },
            onComplete: { [weak self] error in
                guard let self else { return }
                Task { await self.handleTaskComplete(error: error) }
            }
        )
        self.worker = worker
        worker.start(fromByte: bytesDownloaded)
    }

    func waitUntilBytes(_ minBytes: Int64) async throws {
        if isComplete { return }
        if let failure { throw failure }
        if bytesDownloaded >= minBytes { return }
        if isCancelled { throw ProgressiveDownloadError.cancelled }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            byteWaiters.append((minBytes, continuation))
        }
    }

    func waitForCompletion() async throws -> URL {
        if let finalURL { return finalURL }
        if let failure { throw failure }
        if isCancelled { throw ProgressiveDownloadError.cancelled }

        return try await withCheckedThrowingContinuation { continuation in
            completionWaiters.append(continuation)
        }
    }

    func makeProgressStream() -> AsyncStream<ProgressiveDownloadProgress> {
        let id = UUID()
        return AsyncStream { continuation in
            progressContinuations[id] = continuation
            continuation.yield(currentProgress())
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeProgressContinuation(id) }
            }
        }
    }

    func currentProgress() -> ProgressiveDownloadProgress {
        ProgressiveDownloadProgress(
            bytesDownloaded: bytesDownloaded,
            expectedBytes: expectedBytes,
            isComplete: isComplete
        )
    }

    func bytesDownloadedCount() -> Int64 {
        bytesDownloaded
    }

    func expectedByteCount() -> Int64? {
        expectedBytes
    }

    func cancelAndDeletePartial() {
        isCancelled = true
        worker?.cancel()
        worker = nil
        try? fileHandle?.close()
        fileHandle = nil
        try? FileManager.default.removeItem(at: partialURL)
        fail(with: ProgressiveDownloadError.cancelled)
    }

    private func handleResponse(expectedBytes: Int64?, fileExtension: String) {
        if let expectedBytes {
            self.expectedBytes = expectedBytes
        }
        downloadedFileExtension = fileExtension
        broadcastProgress()
        resumeByteWaiters()
    }

    private func appendData(_ data: Data) throws {
        guard let fileHandle else { throw ProgressiveDownloadError.cancelled }
        try fileHandle.write(contentsOf: data)
        bytesDownloaded += Int64(data.count)
        broadcastProgress()
        resumeByteWaiters()
    }

    private func handleTaskComplete(error: Error?) async {
        if let error {
            if (error as NSError).code == NSURLErrorCancelled {
                return
            }
            logger.error("Download failed: \(error.localizedDescription)")
            scheduleRetry()
            return
        }

        guard let fileHandle else {
            fail(with: ProgressiveDownloadError.invalidResponse)
            return
        }

        do {
            try fileHandle.close()
            self.fileHandle = nil

            let ext = downloadedFileExtension
            let destinationURL = AudioCache.audioDirectory
                .appendingPathComponent(trackID.uuidString)
                .appendingPathExtension(ext)

            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: partialURL, to: destinationURL)
            AudioCache.touch(destinationURL)

            isComplete = true
            finalURL = destinationURL
            worker = nil
            broadcastProgress()

            await AudioCache.shared.sessionDidComplete(trackID: trackID)

            for waiter in completionWaiters {
                waiter.resume(returning: destinationURL)
            }
            completionWaiters.removeAll()
            byteWaiters.removeAll()
        } catch {
            fail(with: error)
        }
    }

    private func fail(with error: Error) {
        guard !isComplete else { return }
        failure = error
        worker?.cancel()
        worker = nil
        try? fileHandle?.close()
        fileHandle = nil

        for waiter in byteWaiters {
            waiter.continuation.resume(throwing: error)
        }
        byteWaiters.removeAll()

        for waiter in completionWaiters {
            waiter.resume(throwing: error)
        }
        completionWaiters.removeAll()

        for continuation in progressContinuations.values {
            continuation.finish()
        }
        progressContinuations.removeAll()
    }

    private func scheduleRetry() {
        guard !isComplete, !isCancelled else { return }
        retryCount += 1
        guard retryCount <= 3 else {
            fail(with: ProgressiveDownloadError.exhaustedRetries)
            return
        }
        worker?.cancel()
        worker = nil
        start()
    }

    private func removeProgressContinuation(_ id: UUID) {
        progressContinuations[id] = nil
    }

    private func broadcastProgress() {
        let progress = currentProgress()
        for continuation in progressContinuations.values {
            continuation.yield(progress)
        }
        if isComplete {
            for continuation in progressContinuations.values {
                continuation.finish()
            }
            progressContinuations.removeAll()
        }
    }

    private func resumeByteWaiters() {
        var remaining: [(threshold: Int64, continuation: CheckedContinuation<Void, Error>)] = []
        for waiter in byteWaiters {
            if bytesDownloaded >= waiter.threshold || isComplete {
                waiter.continuation.resume()
            } else if let failure {
                waiter.continuation.resume(throwing: failure)
            } else if isCancelled {
                waiter.continuation.resume(throwing: ProgressiveDownloadError.cancelled)
            } else {
                remaining.append(waiter)
            }
        }
        byteWaiters = remaining
    }
}

final class ProgressiveAudioAsset: Sendable {
    let trackID: UUID
    let partialURL: URL
    private let session: ProgressiveDownloadSession

    init(session: ProgressiveDownloadSession) {
        self.trackID = session.trackID
        self.partialURL = session.partialURL
        self.session = session
    }

    func progressStream() -> AsyncStream<ProgressiveDownloadProgress> {
        AsyncStream { continuation in
            Task {
                let stream = await session.makeProgressStream()
                for await value in stream {
                    continuation.yield(value)
                }
                continuation.finish()
            }
        }
    }

    func waitUntilBuffered(minBytes: Int64 = ProgressivePlayback.initialBufferBytes) async throws {
        try await session.waitUntilBytes(minBytes)
    }

    func waitUntilComplete() async throws -> URL {
        try await session.waitForCompletion()
    }

    func bytesDownloaded() async -> Int64 {
        await session.bytesDownloadedCount()
    }

    func expectedBytes() async -> Int64? {
        await session.expectedByteCount()
    }

    func isComplete() async -> Bool {
        await session.isComplete
    }

    func waitUntilBytes(_ count: Int64) async throws {
        try await session.waitUntilBytes(count)
    }
}

// MARK: - URLSession worker

private final class ProgressiveDownloadWorker: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let remoteURL: URL
    private let onResponse: @Sendable (Int64?, String) -> Void
    private let onData: @Sendable (Data) -> Void
    private let onComplete: @Sendable (Error?) -> Void

    private var urlSession: URLSession!
    private var dataTask: URLSessionDataTask?
    private(set) var responseExt = "mp3"
    private var receivedValidatedResponse = false
    private var startOffset: Int64 = 0

    init(
        remoteURL: URL,
        onResponse: @escaping @Sendable (Int64?, String) -> Void,
        onData: @escaping @Sendable (Data) -> Void,
        onComplete: @escaping @Sendable (Error?) -> Void
    ) {
        self.remoteURL = remoteURL
        self.onResponse = onResponse
        self.onData = onData
        self.onComplete = onComplete
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 600
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func start(fromByte offset: Int64) {
        startOffset = offset
        receivedValidatedResponse = false
        var request = URLRequest(url: remoteURL)
        if offset > 0 {
            request.setValue("bytes=\(offset)-", forHTTPHeaderField: "Range")
        }
        let task = urlSession.dataTask(with: request)
        dataTask = task
        task.resume()
    }

    func cancel() {
        dataTask?.cancel()
        dataTask = nil
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            onComplete(ProgressiveDownloadError.invalidResponse)
            return
        }

        guard (200...299).contains(http.statusCode) || http.statusCode == 206 else {
            completionHandler(.cancel)
            onComplete(ProgressiveDownloadError.invalidResponse)
            return
        }

        if let contentType = http.value(forHTTPHeaderField: "Content-Type"),
           let ext = AudioEngineService.ext(forContentType: contentType) {
            responseExt = ext
        }

        let expectedBytes: Int64?
        if let contentRange = http.value(forHTTPHeaderField: "Content-Range"),
           let totalPart = contentRange.split(separator: "/").last,
           totalPart != "*",
           let total = Int64(totalPart) {
            expectedBytes = total
        } else if let contentLength = http.value(forHTTPHeaderField: "Content-Length").flatMap(Int64.init) {
            expectedBytes = startOffset > 0 ? startOffset + contentLength : contentLength
        } else {
            expectedBytes = nil
        }

        receivedValidatedResponse = true
        onResponse(expectedBytes, responseExt)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        onData(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if !receivedValidatedResponse, error == nil {
            onComplete(ProgressiveDownloadError.invalidResponse)
            return
        }
        onComplete(error)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
