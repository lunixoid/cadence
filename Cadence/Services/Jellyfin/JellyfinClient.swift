import Foundation
import SwiftUI
import os.log

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

// MARK: - Client

final class JellyfinClient: Sendable {
    private let serverURL: URL
    private let token: String
    private let userID: String
    private let deviceID: String
    private let session: URLSession

    private static let clientName = "Cadence"
    private static let clientVersion = "1.0.0"

    init(server: JellyfinServer) throws {
        guard let url = server.url else { throw JellyfinError.invalidURL }
        self.serverURL = url
        self.token = server.token
        self.userID = server.userID
        self.deviceID = Self.deviceID()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    // MARK: - Authentication

    static func authenticate(serverURLString: String, username: String, password: String) async throws -> JellyfinServer {
        guard let serverURL = URL(string: serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw JellyfinError.invalidURL
        }

        let deviceID = Self.deviceID()
        let endpoint = serverURL.appendingPathComponent("Users/AuthenticateByName")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authHeader(token: nil, deviceID: deviceID), forHTTPHeaderField: "X-Emby-Authorization")

        let body: [String: String] = ["Username": username, "Pw": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response)

        let auth = try JSONDecoder().decode(JellyfinAuthResponse.self, from: data)

        let server = JellyfinServer(
            name: serverURL.host ?? serverURLString,
            urlString: serverURLString.trimmingCharacters(in: .whitespacesAndNewlines),
            userID: auth.user.id,
            username: username,
            token: auth.accessToken
        )

        KeychainHelper.save(token: auth.accessToken, account: "jellyfin-\(server.id)")
        return server
    }

    static func authenticateWithAPIKey(serverURLString: String, apiKey: String) async throws -> JellyfinServer {
        guard let serverURL = URL(string: serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw JellyfinError.invalidURL
        }

        let deviceID = Self.deviceID()
        let endpoint = serverURL.appendingPathComponent("Users/Me")
        var request = URLRequest(url: endpoint)
        request.setValue(authHeader(token: apiKey, deviceID: deviceID), forHTTPHeaderField: "X-Emby-Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response)

        let user = try JSONDecoder().decode(JellyfinUser.self, from: data)

        let server = JellyfinServer(
            name: serverURL.host ?? serverURLString,
            urlString: serverURLString.trimmingCharacters(in: .whitespacesAndNewlines),
            userID: user.id,
            username: "API Key",
            token: apiKey
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

    func getAlbumTracks(albumID: String) async throws -> [JellyfinItem] {
        var components = itemsURLComponents()
        components.queryItems?.append(contentsOf: [
            URLQueryItem(name: "ParentId", value: albumID),
            URLQueryItem(name: "IncludeItemTypes", value: "Audio"),
            URLQueryItem(name: "SortBy", value: "ParentIndexNumber,IndexNumber,SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Fields", value: "MediaSources,RunTimeTicks"),
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

        _ = try? await session.data(for: request)
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

        _ = try? await session.data(for: request)
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

        _ = try? await session.data(for: request)
    }

    // MARK: - Helpers

    private func itemsURLComponents() -> URLComponents {
        var components = URLComponents(
            url: serverURL.appendingPathComponent("Users/\(userID)/Items"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "api_key", value: token)]
        return components
    }

    private func fetchItems(from components: URLComponents) async throws -> [JellyfinItem] {
        guard let url = components.url else { throw JellyfinError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue(authHeader(token: token, deviceID: deviceID), forHTTPHeaderField: "X-Emby-Authorization")

        let (data, response) = try await session.data(for: request)
        try Self.validateHTTPResponse(response)

        do {
            let decoded = try JSONDecoder().decode(JellyfinItemsResponse.self, from: data)
            return decoded.items
        } catch {
            // Some endpoints (like Artists) return a flat array
            if let items = try? JSONDecoder().decode([JellyfinItem].self, from: data) {
                return items
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
        let albumID = UUID(uuidString: item.id) ?? UUID()
        return Album(
            id: albumID,
            title: item.name,
            artist: item.albumArtist ?? item.albumArtists?.first?.name ?? "Неизвестный артист",
            year: item.productionYear,
            accentColors: accentColors,
            coverURL: artworkURL(itemID: item.id, maxWidth: 300)
        )
    }

    func convertToTrack(item: JellyfinItem, albumID: UUID) -> Track? {
        guard let streamURL = streamURL(itemID: item.id) else { return nil }
        return Track(
            id: UUID(uuidString: item.id) ?? UUID(),
            index: item.indexNumber ?? 0,
            title: item.name,
            artist: item.artists?.first ?? item.albumArtist ?? "Неизвестный артист",
            albumID: albumID,
            duration: item.durationSeconds,
            fileURL: streamURL,
            discNumber: item.parentIndexNumber ?? 1
        )
    }
}
