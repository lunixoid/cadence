import AVFoundation
import Foundation
import Network
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

/// Writes the progressive HTTP body in arrival order on a serial queue.
/// Hopping each `didReceive` through unstructured `Task { await actor.append }`
/// can reorder chunks and punch holes in the MP3 bitstream.
private final class ProgressiveFileWriter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.personal.cadence.progressive-write")
    private var handle: FileHandle?
    private var offset: Int64 = 0
    private var epoch: Int = 0
    private var failed = false

    var onWrote: (@Sendable (Int64, Int) -> Void)?
    var onFailed: (@Sendable (Error) -> Void)?

    init(handle: FileHandle) {
        self.handle = handle
    }

    func write(_ data: Data) {
        queue.async { self.performWrite(data) }
    }

    /// Enqueue a truncate. Must be queued before any subsequent `write` of the
    /// new body so FIFO order is: truncate → new bytes.
    func truncateToZero() {
        queue.async { self.performTruncate() }
    }

    func currentOffset() -> Int64 {
        queue.sync { offset }
    }

    func finish() async throws -> Int64 {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.handle?.synchronize()
                    try self.handle?.close()
                    self.handle = nil
                    continuation.resume(returning: self.offset)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func abandon() {
        queue.async {
            try? self.handle?.close()
            self.handle = nil
        }
    }

    private func performWrite(_ data: Data) {
        guard !failed, let handle else { return }
        do {
            try handle.write(contentsOf: data)
            offset += Int64(data.count)
            onWrote?(offset, epoch)
        } catch {
            failed = true
            onFailed?(error)
        }
    }

    private func performTruncate() {
        guard !failed, let handle else { return }
        do {
            try handle.truncate(atOffset: 0)
            try handle.seek(toOffset: 0)
            offset = 0
            epoch += 1
            onWrote?(0, epoch)
        } catch {
            failed = true
            onFailed?(error)
        }
    }
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
    private let writer: ProgressiveFileWriter
    private var byteEpoch: Int = 0
    private var downloadedFileExtension = "mp3"

    init(trackID: UUID, remoteURL: URL, partialURL: URL) throws {
        self.trackID = trackID
        self.remoteURL = remoteURL
        self.partialURL = partialURL

        let directory = partialURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: partialURL)
        FileManager.default.createFile(atPath: partialURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: partialURL)
        self.writer = ProgressiveFileWriter(handle: handle)
    }

    func start() {
        guard !isComplete, worker == nil else { return }
        let writer = self.writer
        writer.onWrote = { [weak self] offset, epoch in
            Task { await self?.noteBytes(offset, epoch: epoch) }
        }
        writer.onFailed = { [weak self] error in
            Task { await self?.fail(with: error) }
        }
        let fromByte = writer.currentOffset()
        bytesDownloaded = fromByte
        let worker = ProgressiveDownloadWorker(
            remoteURL: remoteURL,
            onResponse: { [weak self] expectedBytes, fileExtension in
                guard let self else { return }
                Task { await self.handleResponse(expectedBytes: expectedBytes, fileExtension: fileExtension) }
            },
            onRewriteFromStart: {
                writer.truncateToZero()
            },
            onData: { data in
                writer.write(data)
            },
            onComplete: { [weak self] error in
                guard let self else { return }
                Task { await self.handleTaskComplete(error: error) }
            }
        )
        self.worker = worker
        worker.start(fromByte: fromByte)
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
        writer.abandon()
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

    private func noteBytes(_ absoluteOffset: Int64, epoch: Int) {
        if epoch < byteEpoch { return }
        if epoch > byteEpoch {
            byteEpoch = epoch
            bytesDownloaded = absoluteOffset
        } else {
            bytesDownloaded = max(bytesDownloaded, absoluteOffset)
        }
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

        do {
            let finalOffset = try await writer.finish()
            bytesDownloaded = finalOffset

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
        writer.abandon()

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

// MARK: - URLSession / insecure NW worker

private final class ProgressiveDownloadWorker: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let remoteURL: URL
    private let onResponse: @Sendable (Int64?, String) -> Void
    private let onRewriteFromStart: @Sendable () -> Void
    private let onData: @Sendable (Data) -> Void
    private let onComplete: @Sendable (Error?) -> Void

    private var urlSession: URLSession!
    private var dataTask: URLSessionDataTask?
    private var insecureTask: Task<Void, Never>?
    private var insecureConnection: NWConnection?
    private(set) var responseExt = "mp3"
    private var receivedValidatedResponse = false
    private var startOffset: Int64 = 0

    init(
        remoteURL: URL,
        onResponse: @escaping @Sendable (Int64?, String) -> Void,
        onRewriteFromStart: @escaping @Sendable () -> Void,
        onData: @escaping @Sendable (Data) -> Void,
        onComplete: @escaping @Sendable (Error?) -> Void
    ) {
        self.remoteURL = remoteURL
        self.onResponse = onResponse
        self.onRewriteFromStart = onRewriteFromStart
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

        // URLSession TLS overrides fail for private CAs (esp. on iOS) — use NWConnection.
        if JellyfinTLSSettings.allowsUntrustedCertificates {
            startInsecureStream(request)
            return
        }

        let task = urlSession.dataTask(with: request)
        dataTask = task
        task.resume()
    }

    func cancel() {
        dataTask?.cancel()
        dataTask = nil
        insecureConnection?.cancel()
        insecureConnection = nil
        insecureTask?.cancel()
        insecureTask = nil
    }

    private func startInsecureStream(_ request: URLRequest) {
        insecureTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await JellyfinInsecureHTTPS.stream(
                    for: request,
                    onConnection: { [weak self] connection in
                        self?.insecureConnection = connection
                    },
                    onResponse: { [weak self] response in
                        try self?.handleHTTPResponse(response)
                    },
                    onData: { [weak self] data in
                        self?.onData(data)
                    }
                )
                guard !Task.isCancelled else { return }
                self.onComplete(nil)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.onComplete(error)
            }
        }
    }

    private func handleHTTPResponse(_ http: HTTPURLResponse) throws {
        guard (200...299).contains(http.statusCode) || http.statusCode == 206 else {
            throw ProgressiveDownloadError.invalidResponse
        }

        if let contentType = http.value(forHTTPHeaderField: "Content-Type"),
           let ext = AudioEngineService.ext(forContentType: contentType) {
            responseExt = ext
        }

        let rangeHeader = http.value(forHTTPHeaderField: "Content-Range") ?? ""

        // Server ignored Range and sent the whole file. Truncate before any
        // body bytes are written so we don't append a second copy.
        if startOffset > 0 && http.statusCode == 200 {
            onRewriteFromStart()
        }

        let expectedBytes: Int64?
        if http.statusCode == 206,
           let totalPart = rangeHeader.split(separator: "/").last,
           totalPart != "*",
           let total = Int64(totalPart) {
            expectedBytes = total
        } else if let contentLength = http.value(forHTTPHeaderField: "Content-Length").flatMap(Int64.init) {
            // 200 is a full body even if we asked for a Range.
            expectedBytes = http.statusCode == 200 ? contentLength : startOffset + contentLength
        } else {
            expectedBytes = nil
        }

        receivedValidatedResponse = true
        onResponse(expectedBytes, responseExt)
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

        do {
            try handleHTTPResponse(http)
            completionHandler(.allow)
        } catch {
            completionHandler(.cancel)
            onComplete(error)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        onData(data)
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        JellyfinURLSessionFactory.handleServerTrustChallenge(challenge, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if !receivedValidatedResponse, error == nil {
            onComplete(ProgressiveDownloadError.invalidResponse)
            return
        }
        onComplete(error)
    }
}
