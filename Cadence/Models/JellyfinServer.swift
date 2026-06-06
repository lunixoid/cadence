import Foundation

struct JellyfinServer: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var urlString: String
    var userID: String
    var username: String
    var token: String
    var isActive: Bool

    var url: URL? { URL(string: urlString) }

    init(id: UUID = UUID(), name: String, urlString: String, userID: String, username: String = "", token: String, isActive: Bool = false) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.userID = userID
        self.username = username
        self.token = token
        self.isActive = isActive
    }
}
