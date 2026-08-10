import Foundation

struct JellyfinServer: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var urlString: String
    var userID: String
    var username: String
    var token: String
    var isActive: Bool
    /// When true, URLSession accepts the server's TLS certificate even if the CA is not in the trust store
    /// (private CA / self-signed). Required for many self-hosted Jellyfin setups, especially on iOS.
    var allowsUntrustedCertificate: Bool

    var url: URL? { URL(string: urlString) }

    init(
        id: UUID = UUID(),
        name: String,
        urlString: String,
        userID: String,
        username: String = "",
        token: String,
        isActive: Bool = false,
        allowsUntrustedCertificate: Bool = false
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.userID = userID
        self.username = username
        self.token = token
        self.isActive = isActive
        self.allowsUntrustedCertificate = allowsUntrustedCertificate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        urlString = try container.decode(String.self, forKey: .urlString)
        userID = try container.decode(String.self, forKey: .userID)
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        token = try container.decode(String.self, forKey: .token)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        allowsUntrustedCertificate = try container.decodeIfPresent(Bool.self, forKey: .allowsUntrustedCertificate) ?? false
    }
}
