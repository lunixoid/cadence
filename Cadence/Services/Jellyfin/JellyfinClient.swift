import Foundation
import SwiftUI
import Network
import os.log
import Security

private let logger = Logger(subsystem: "dev.personal.cadence", category: "Jellyfin")

// MARK: - Response Models

private struct JellyfinAuthResponse: Decodable {
    let accessToken: String
    let user: JellyfinUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "AccessToken"
        case user = "User"
    }
}

private struct JellyfinUser: Decodable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}

private struct JellyfinItemsResponse: Decodable {
    let items: [JellyfinItem]
    let totalRecordCount: Int

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}

struct JellyfinItem: Decodable {
    let id: String
    let name: String
    let type: String?
    let albumArtist: String?
    let albumArtists: [JellyfinNamedObject]?
    let artists: [String]?
    let album: String?
    let albumId: String?
    let runTimeTicks: Int64?
    let indexNumber: Int?
    let parentIndexNumber: Int?
    let productionYear: Int?
    let imageTags: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case albumArtist = "AlbumArtist"
        case albumArtists = "AlbumArtists"
        case artists = "Artists"
        case album = "Album"
        case albumId = "AlbumId"
        case runTimeTicks = "RunTimeTicks"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
        case productionYear = "ProductionYear"
        case imageTags = "ImageTags"
    }

    var durationSeconds: TimeInterval {
        guard let ticks = runTimeTicks else { return 0 }
        return TimeInterval(ticks) / 10_000_000
    }
}

struct JellyfinNamedObject: Decodable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}

// MARK: - Errors

enum JellyfinError: LocalizedError {
    case invalidURL
    case authFailed(String)
    case httpError(Int)
    case decodingFailed(Error)
    case noActiveServer

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Неверный URL сервера"
        case .authFailed(let msg): return "Ошибка авторизации: \(msg)"
        case .httpError(let code): return "Ошибка сервера: HTTP \(code)"
        case .decodingFailed: return "Ошибка разбора ответа сервера"
        case .noActiveServer: return "Нет активного сервера Jellyfin"
        }
    }
}

// MARK: - TLS trust (private CA / self-signed)

enum JellyfinTLSSettings {
    /// Process-wide flag for artwork/stream downloaders that don't own server config.
    nonisolated(unsafe) static var allowsUntrustedCertificates = false
}

/// HTTPS via Network.framework with disabled peer verification.
/// URLSession custom trust overrides still fail on iOS with errSSLFatalAlert (-9802) for private CAs,
/// even after SecTrust evaluates successfully — so untrusted servers use NWConnection instead.
enum JellyfinInsecureHTTPS {
    static func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let connection = try makeConnection(for: request)
        do {
            try await waitUntilReady(connection)
            guard let host = request.url?.host else { throw URLError(.badURL) }
            let wireRequest = try buildHTTPRequest(request, host: host)
            try await send(wireRequest, on: connection)
            let raw = try await receiveAll(on: connection)
            connection.cancel()
            guard let url = request.url else { throw URLError(.badURL) }
            return try parseHTTPResponse(raw, url: url)
        } catch {
            connection.cancel()
            throw error
        }
    }

    /// Streams response body as it arrives (for progressive audio downloads).
    /// Calls `onConnection` immediately so the caller can cancel the NWConnection.
    static func stream(
        for request: URLRequest,
        onConnection: @escaping @Sendable (NWConnection) -> Void,
        onResponse: @escaping @Sendable (HTTPURLResponse) throws -> Void,
        onData: @escaping @Sendable (Data) -> Void
    ) async throws {
        guard let url = request.url, let host = url.host else {
            throw URLError(.badURL)
        }
        let connection = try makeConnection(for: request)
        onConnection(connection)

        do {
            try await waitUntilReady(connection)
            let wireRequest = try buildHTTPRequest(request, host: host)
            try await send(wireRequest, on: connection)

            var buffer = Data()
            var headersParsed = false
            while true {
                let (chunk, isComplete) = try await receiveChunk(on: connection)
                if !headersParsed {
                    buffer.append(chunk)
                    guard let headerRange = buffer.range(of: Data("\r\n\r\n".utf8)) else {
                        if isComplete { throw URLError(.badServerResponse) }
                        continue
                    }
                    let headerData = buffer.subdata(in: buffer.startIndex..<headerRange.lowerBound)
                    let bodyPrefix = buffer.subdata(in: headerRange.upperBound..<buffer.endIndex)
                    buffer = Data()
                    headersParsed = true

                    let response = try parseHTTPURLResponse(headerData: headerData, url: url)
                    try onResponse(response)
                    if !bodyPrefix.isEmpty {
                        onData(bodyPrefix)
                    }
                } else if !chunk.isEmpty {
                    onData(chunk)
                }
                if isComplete { break }
            }
            connection.cancel()
        } catch {
            connection.cancel()
            throw error
        }
    }

    private static func makeConnection(for request: URLRequest) throws -> NWConnection {
        guard let url = request.url, let host = url.host else {
            throw URLError(.badURL)
        }
        let port = UInt16(url.port ?? (url.scheme == "http" ? 80 : 443))
        let useTLS = (url.scheme ?? "https").lowercased() != "http"

        let parameters: NWParameters
        if useTLS {
            let tls = NWProtocolTLS.Options()
            let securityOptions = tls.securityProtocolOptions
            sec_protocol_options_set_peer_authentication_required(securityOptions, false)
            sec_protocol_options_set_verify_block(securityOptions, { _, _, complete in
                complete(true)
            }, DispatchQueue.global(qos: .userInitiated))
            parameters = NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
        } else {
            parameters = NWParameters.tcp
        }

        return NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: parameters
        )
    }

    private static func waitUntilReady(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            final class ResumeGate: @unchecked Sendable {
                private let lock = NSLock()
                private var resumed = false
                private let continuation: CheckedContinuation<Void, Error>

                init(_ continuation: CheckedContinuation<Void, Error>) {
                    self.continuation = continuation
                }

                func resume(_ result: Result<Void, Error>) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(with: result)
                }
            }

            let gate = ResumeGate(continuation)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    gate.resume(.success(()))
                case .failed(let error):
                    gate.resume(.failure(error))
                case .cancelled:
                    gate.resume(.failure(URLError(.cancelled)))
                default:
                    break
                }
            }
            connection.start(queue: DispatchQueue.global(qos: .userInitiated))
        }
    }

    private static func send(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private static func receiveChunk(on connection: NWConnection) async throws -> (Data, Bool) {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1024 * 256) { content, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (content ?? Data(), isComplete))
            }
        }
    }

    private static func receiveAll(on connection: NWConnection) async throws -> Data {
        var buffer = Data()
        while true {
            let (chunk, isComplete) = try await receiveChunk(on: connection)
            buffer.append(chunk)
            if isComplete { break }
        }
        return buffer
    }

    private static func buildHTTPRequest(_ request: URLRequest, host: String) throws -> Data {
        guard let url = request.url else { throw URLError(.badURL) }
        let method = request.httpMethod ?? "GET"
        var path = url.path
        if path.isEmpty { path = "/" }
        if let query = url.query, !query.isEmpty {
            path += "?\(query)"
        }

        var headerLines: [String] = [
            "\(method) \(path) HTTP/1.1",
            "Host: \(host)",
            "Connection: close",
            "Accept: */*",
        ]

        var hasContentLength = false
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                let lower = key.lowercased()
                if lower == "host" || lower == "connection" { continue }
                if lower == "content-length" { hasContentLength = true }
                headerLines.append("\(key): \(value)")
            }
        }

        let body = request.httpBody ?? Data()
        if !body.isEmpty, !hasContentLength {
            headerLines.append("Content-Length: \(body.count)")
        }

        var message = headerLines.joined(separator: "\r\n")
        message += "\r\n\r\n"
        var data = Data(message.utf8)
        data.append(body)
        return data
    }

    private static func parseHTTPURLResponse(headerData: Data, url: URL) throws -> HTTPURLResponse {
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }

        let lines = headerText.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let statusLine = lines.first else { throw URLError(.badServerResponse) }
        let statusParts = statusLine.split(separator: " ")
        guard statusParts.count >= 2, let statusCode = Int(statusParts[1]) else {
            throw URLError(.badServerResponse)
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let sep = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<sep]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: sep)...]).trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        return HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
    }

    private static func parseHTTPResponse(_ raw: Data, url: URL) throws -> (Data, URLResponse) {
        guard let headerRange = raw.range(of: Data("\r\n\r\n".utf8)) else {
            throw URLError(.badServerResponse)
        }
        let headerData = raw.subdata(in: raw.startIndex..<headerRange.lowerBound)
        let body = raw.subdata(in: headerRange.upperBound..<raw.endIndex)
        let response = try parseHTTPURLResponse(headerData: headerData, url: url)
        return (body, response)
    }
}

enum JellyfinURLSessionFactory {
    static func data(
        for request: URLRequest,
        allowUntrustedCertificate: Bool
    ) async throws -> (Data, URLResponse) {
        if allowUntrustedCertificate || JellyfinTLSSettings.allowsUntrustedCertificates {
            return try await JellyfinInsecureHTTPS.data(for: request)
        }
        return try await URLSession.shared.data(for: request)
    }

    static func handleServerTrustChallenge(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Streaming downloaders still on URLSession — accept trust when allowed.
        guard JellyfinTLSSettings.allowsUntrustedCertificates,
              challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        if let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate], let ca = chain.last {
            SecTrustSetAnchorCertificates(trust, [ca] as CFArray)
            SecTrustSetAnchorCertificatesOnly(trust, false)
        }
        if let exceptions = SecTrustCopyExceptions(trust) {
            _ = SecTrustSetExceptions(trust, exceptions)
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    static func normalizedServerURL(from raw: String) -> URL? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if URL(string: trimmed)?.scheme == nil {
            trimmed = "https://\(trimmed)"
        }
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return URL(string: trimmed)
    }
}

// MARK: - Client

final class JellyfinClient: Sendable {
    private let serverURL: URL
    private let token: String
    private let userID: String
    private let deviceID: String
    private let allowsUntrustedCertificate: Bool

    private static let clientName = "Cadence"
    private static let clientVersion = "1.0.0"

    init(server: JellyfinServer) throws {
        guard let url = JellyfinURLSessionFactory.normalizedServerURL(from: server.urlString) ?? server.url else {
            throw JellyfinError.invalidURL
        }
        self.serverURL = url
        self.token = server.token
        self.userID = server.userID
        self.deviceID = Self.deviceID()
        self.allowsUntrustedCertificate = server.allowsUntrustedCertificate
        JellyfinTLSSettings.allowsUntrustedCertificates = server.allowsUntrustedCertificate
    }

    // MARK: - Authentication

    static func authenticate(
        serverURLString: String,
        username: String,
        password: String,
        allowsUntrustedCertificate: Bool = false
    ) async throws -> JellyfinServer {
        guard let serverURL = JellyfinURLSessionFactory.normalizedServerURL(from: serverURLString) else {
            throw JellyfinError.invalidURL
        }

        let normalizedURLString = serverURL.absoluteString
        let deviceID = Self.deviceID()
        let endpoint = serverURL.appendingPathComponent("Users/AuthenticateByName")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authHeader(token: nil, deviceID: deviceID), forHTTPHeaderField: "X-Emby-Authorization")

        let body: [String: String] = ["Username": username, "Pw": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await JellyfinURLSessionFactory.data(
            for: request,
            allowUntrustedCertificate: allowsUntrustedCertificate
        )
        try validateHTTPResponse(response)

        let auth = try JSONDecoder().decode(JellyfinAuthResponse.self, from: data)

        let server = JellyfinServer(
            name: serverURL.host ?? normalizedURLString,
            urlString: normalizedURLString,
            userID: auth.user.id,
            username: username,
            token: auth.accessToken,
            allowsUntrustedCertificate: allowsUntrustedCertificate
        )

        KeychainHelper.save(token: auth.accessToken, account: "jellyfin-\(server.id)")
        return server
    }

    static func authenticateWithAPIKey(
        serverURLString: String,
        apiKey: String,
        allowsUntrustedCertificate: Bool = false
    ) async throws -> JellyfinServer {
        guard let serverURL = JellyfinURLSessionFactory.normalizedServerURL(from: serverURLString) else {
            throw JellyfinError.invalidURL
        }

        let normalizedURLString = serverURL.absoluteString
        let deviceID = Self.deviceID()
        let endpoint = serverURL.appendingPathComponent("Users/Me")
        var request = URLRequest(url: endpoint)
        request.setValue(authHeader(token: apiKey, deviceID: deviceID), forHTTPHeaderField: "X-Emby-Authorization")

        let (data, response) = try await JellyfinURLSessionFactory.data(
            for: request,
            allowUntrustedCertificate: allowsUntrustedCertificate
        )
        try validateHTTPResponse(response)

        let user = try JSONDecoder().decode(JellyfinUser.self, from: data)

        let server = JellyfinServer(
            name: serverURL.host ?? normalizedURLString,
            urlString: normalizedURLString,
            userID: user.id,
            username: "API Key",
            token: apiKey,
            allowsUntrustedCertificate: allowsUntrustedCertificate
        )

        KeychainHelper.save(token: apiKey, account: "jellyfin-\(server.id)")
        return server
    }

    // MARK: - Library

    func getAlbums(limit: Int = 500, offset: Int = 0) async throws -> [JellyfinItem] {
        var components = itemsURLComponents()
        components.queryItems?.append(contentsOf: [
            URLQueryItem(name: "IncludeItemTypes", value: "MusicAlbum"),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Limit", value: "\(limit)"),
            URLQueryItem(name: "StartIndex", value: "\(offset)"),
            URLQueryItem(name: "Fields", value: "ProductionYear,ImageTags"),
        ])
        return try await fetchItems(from: components)
    }

    func getAllAudioItems(pageSize: Int = 500) async throws -> [JellyfinItem] {
        var allItems: [JellyfinItem] = []
        var startIndex = 0

        while true {
            var components = itemsURLComponents()
            components.queryItems?.append(contentsOf: [
                URLQueryItem(name: "IncludeItemTypes", value: "Audio"),
                URLQueryItem(name: "SortBy", value: "SortName"),
                URLQueryItem(name: "SortOrder", value: "Ascending"),
                URLQueryItem(name: "Recursive", value: "true"),
                URLQueryItem(name: "Limit", value: "\(pageSize)"),
                URLQueryItem(name: "StartIndex", value: "\(startIndex)"),
                URLQueryItem(name: "Fields", value: "MediaSources,RunTimeTicks,IndexNumber,ParentIndexNumber,Album,AlbumArtist,Artists,ProductionYear,AlbumId,ImageTags"),
            ])

            let (page, totalCount) = try await fetchItemsPage(from: components)
            allItems.append(contentsOf: page)
            startIndex += page.count
            if page.isEmpty || startIndex >= totalCount {
                break
            }
        }

        return allItems
    }

    func getAlbumTracks(albumID: String) async throws -> [JellyfinItem] {
        var components = itemsURLComponents()
        components.queryItems?.append(contentsOf: [
            URLQueryItem(name: "ParentId", value: albumID),
            URLQueryItem(name: "IncludeItemTypes", value: "Audio"),
            URLQueryItem(name: "SortBy", value: "ParentIndexNumber,IndexNumber,SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Fields", value: "MediaSources,RunTimeTicks,IndexNumber,ParentIndexNumber,Album,AlbumArtist,Artists"),
        ])
        return try await fetchItems(from: components)
    }

    func getArtists(limit: Int = 500) async throws -> [JellyfinItem] {
        var components = URLComponents(url: serverURL.appendingPathComponent("Artists"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "userId", value: userID),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Limit", value: "\(limit)"),
        ]
        return try await fetchItems(from: components)
    }

    func getPlaylists() async throws -> [JellyfinItem] {
        var components = itemsURLComponents()
        components.queryItems?.append(contentsOf: [
            URLQueryItem(name: "IncludeItemTypes", value: "Playlist"),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "Recursive", value: "true"),
        ])
        return try await fetchItems(from: components)
    }

    func getPlaylistTracks(playlistID: String) async throws -> [JellyfinItem] {
        var components = URLComponents(
            url: serverURL.appendingPathComponent("Playlists/\(playlistID)/Items"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "userId", value: userID),
            URLQueryItem(name: "Fields", value: "RunTimeTicks"),
        ]
        return try await fetchItems(from: components)
    }

    func markFavorite(itemID: String) async throws {
        var components = URLComponents(
            url: serverURL.appendingPathComponent("UserFavoriteItems/\(itemID)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "userId", value: userID)]
        guard let url = components.url else { throw JellyfinError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(authHeader(token: token, deviceID: deviceID), forHTTPHeaderField: "X-Emby-Authorization")

        let (_, response) = try await data(for: request)
        try Self.validateHTTPResponse(response)
    }

    func unmarkFavorite(itemID: String) async throws {
        var components = URLComponents(
            url: serverURL.appendingPathComponent("UserFavoriteItems/\(itemID)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "userId", value: userID)]
        guard let url = components.url else { throw JellyfinError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(authHeader(token: token, deviceID: deviceID), forHTTPHeaderField: "X-Emby-Authorization")

        let (_, response) = try await data(for: request)
        try Self.validateHTTPResponse(response)
    }

    func getFavoriteItems(limit: Int = 10000) async throws -> [JellyfinItem] {
        var components = itemsURLComponents()
        components.queryItems?.append(contentsOf: [
            URLQueryItem(name: "Filters", value: "IsFavorite"),
            URLQueryItem(name: "IncludeItemTypes", value: "Audio"),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Limit", value: "\(limit)"),
        ])
        return try await fetchItems(from: components)
    }

    func search(query: String, limit: Int = 50) async throws -> [JellyfinItem] {
        var components = itemsURLComponents()
        components.queryItems?.append(contentsOf: [
            URLQueryItem(name: "SearchTerm", value: query),
            URLQueryItem(name: "IncludeItemTypes", value: "Audio,MusicAlbum,MusicArtist"),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Limit", value: "\(limit)"),
        ])
        return try await fetchItems(from: components)
    }

    // MARK: - Streaming

    func streamURL(itemID: String) -> URL? {
        var components = URLComponents(
            url: serverURL.appendingPathComponent("Audio/\(itemID)/universal"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "userId", value: userID),
            URLQueryItem(name: "api_key", value: token),
            URLQueryItem(name: "deviceId", value: deviceID),
            URLQueryItem(name: "MaxStreamingBitrate", value: "140000000"),
            URLQueryItem(name: "AudioCodec", value: "flac,aac,mp3,alac"),
            URLQueryItem(name: "Container", value: "flac,mp4,m4a,aac,mp3,wav"),
        ]
        return components?.url
    }

    /// Original file download (no transcoding). Requires EnableContentDownloading on the server.
    func originalFileURL(itemID: String) -> URL? {
        var components = URLComponents(
            url: serverURL.appendingPathComponent("Items/\(itemID)/Download"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: token),
        ]
        return components?.url
    }

    /// Original bitstream via stream endpoint (`static=true` disables transcoding).
    func staticStreamURL(itemID: String) -> URL? {
        var components = URLComponents(
            url: serverURL.appendingPathComponent("Audio/\(itemID)/stream"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "static", value: "true"),
            URLQueryItem(name: "api_key", value: token),
            URLQueryItem(name: "userId", value: userID),
            URLQueryItem(name: "deviceId", value: deviceID),
        ]
        return components?.url
    }

    func artworkURL(itemID: String, maxWidth: Int = 300) -> URL? {
        var components = URLComponents(
            url: serverURL.appendingPathComponent("Items/\(itemID)/Images/Primary"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "maxHeight", value: "\(maxWidth)"),
            URLQueryItem(name: "quality", value: "90"),
            URLQueryItem(name: "api_key", value: token),
        ]
        return components?.url
    }

    // MARK: - Scrobbling

    func reportPlaybackStart(itemID: String) async {
        var components = URLComponents(
            url: serverURL.appendingPathComponent("Sessions/Playing"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "api_key", value: token)]
        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authHeader(token: token, deviceID: deviceID), forHTTPHeaderField: "X-Emby-Authorization")

        let body: [String: Any] = ["ItemId": itemID, "CanSeek": true]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        _ = try? await data(for: request)
    }

    func reportPlaybackProgress(itemID: String, position: TimeInterval, isPaused: Bool = false) async {
        var components = URLComponents(
            url: serverURL.appendingPathComponent("Sessions/Playing/Progress"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "api_key", value: token)]
        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authHeader(token: token, deviceID: deviceID), forHTTPHeaderField: "X-Emby-Authorization")

        let ticks = Int64(position * 10_000_000)
        let body: [String: Any] = ["ItemId": itemID, "PositionTicks": ticks, "IsPaused": isPaused]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        _ = try? await data(for: request)
    }

    func reportPlaybackStopped(itemID: String, position: TimeInterval) async {
        var components = URLComponents(
            url: serverURL.appendingPathComponent("Sessions/Playing/Stopped"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "api_key", value: token)]
        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authHeader(token: token, deviceID: deviceID), forHTTPHeaderField: "X-Emby-Authorization")

        let ticks = Int64(position * 10_000_000)
        let body: [String: Any] = ["ItemId": itemID, "PositionTicks": ticks]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        _ = try? await data(for: request)
    }

    // MARK: - Helpers

    private func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await JellyfinURLSessionFactory.data(
            for: request,
            allowUntrustedCertificate: allowsUntrustedCertificate
        )
    }

    private func itemsURLComponents() -> URLComponents {
        var components = URLComponents(
            url: serverURL.appendingPathComponent("Users/\(userID)/Items"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "api_key", value: token)]
        return components
    }

    private func fetchItems(from components: URLComponents) async throws -> [JellyfinItem] {
        try await fetchItemsPage(from: components).items
    }

    private func fetchItemsPage(from components: URLComponents) async throws -> (items: [JellyfinItem], totalCount: Int) {
        guard let url = components.url else { throw JellyfinError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue(authHeader(token: token, deviceID: deviceID), forHTTPHeaderField: "X-Emby-Authorization")

        let (data, response) = try await data(for: request)
        try Self.validateHTTPResponse(response)

        do {
            let decoded = try JSONDecoder().decode(JellyfinItemsResponse.self, from: data)
            return (decoded.items, decoded.totalRecordCount)
        } catch {
            // Some endpoints (like Artists) return a flat array
            if let items = try? JSONDecoder().decode([JellyfinItem].self, from: data) {
                return (items, items.count)
            }
            throw JellyfinError.decodingFailed(error)
        }
    }

    private static func authHeader(token: String?, deviceID: String) -> String {
        var parts = [
            "MediaBrowser Client=\"\(clientName)\"",
            "Device=\"\(clientName)\"",
            "DeviceId=\"\(deviceID)\"",
            "Version=\"\(clientVersion)\"",
        ]
        if let token {
            parts.append("Token=\"\(token)\"")
        }
        return parts.joined(separator: ", ")
    }

    private func authHeader(token: String, deviceID: String) -> String {
        Self.authHeader(token: token, deviceID: deviceID)
    }

    private static func validateHTTPResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw JellyfinError.authFailed("Неверные учётные данные")
            }
            throw JellyfinError.httpError(http.statusCode)
        }
    }

    private static func deviceID() -> String {
        let key = "cadence.deviceID"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }
}

// MARK: - Library Model Conversion

extension JellyfinClient {
    func convertToAlbum(item: JellyfinItem, accentColors: [Color] = CadenceTheme.placeholderGradientColors) -> Album {
        let albumID = StableIdentity.jellyfinItemID(item.id)
        return Album(
            id: albumID,
            title: item.name,
            artist: item.albumArtist ?? item.albumArtists?.first?.name ?? "Неизвестный артист",
            year: item.productionYear,
            accentColors: accentColors,
            coverURL: artworkURL(itemID: item.id, maxWidth: 300)
        )
    }

    func convertToTrack(item: JellyfinItem, albumID: UUID, positionInAlbum: Int) -> Track? {
        guard let streamURL = streamURL(itemID: item.id) else { return nil }
        return Track(
            id: StableIdentity.jellyfinItemID(item.id),
            index: item.indexNumber ?? positionInAlbum,
            title: item.name,
            artist: item.artists?.first ?? item.albumArtist ?? "Неизвестный артист",
            albumID: albumID,
            duration: item.durationSeconds,
            fileURL: streamURL,
            discNumber: item.parentIndexNumber ?? 1
        )
    }

    func convertToAlbum(from trackItems: [JellyfinItem], albumID: UUID) -> Album? {
        guard let first = trackItems.first else { return nil }
        let title = normalizedTag(first.album) ?? "Unknown Album"
        let artist = normalizedTag(first.albumArtist) ?? first.artists?.first ?? "Unknown Artist"
        let artworkItemID = artworkItemID(for: trackItems)
        return Album(
            id: albumID,
            title: title,
            artist: artist,
            year: trackItems.compactMap(\.productionYear).first,
            coverURL: artworkURL(itemID: artworkItemID, maxWidth: 300)
        )
    }

    func artworkItemID(for trackItems: [JellyfinItem]) -> String {
        if let withCover = trackItems.first(where: { $0.imageTags?["Primary"] != nil }) {
            return withCover.id
        }
        return trackItems[0].id
    }

    func albumGroupKey(for item: JellyfinItem) -> String {
        let title = normalizedTag(item.album) ?? "Unknown Album"
        let artist = normalizedTag(item.albumArtist) ?? item.artists?.first ?? "Unknown Artist"
        return "\(title.lowercased())|\(artist.lowercased())"
    }

    func cadenceAlbumID(for firstItem: JellyfinItem) -> UUID {
        let title = normalizedTag(firstItem.album) ?? "Unknown Album"
        let artist = normalizedTag(firstItem.albumArtist) ?? firstItem.artists?.first ?? "Unknown Artist"
        return StableIdentity.jellyfinTaggedAlbumID(title: title, artist: artist)
    }

    private func normalizedTag(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
