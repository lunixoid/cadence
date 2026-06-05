import Foundation

struct Playlist: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var trackIDs: [UUID]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, trackIDs: [UUID] = [], createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.trackIDs = trackIDs
        self.createdAt = createdAt
    }
}
