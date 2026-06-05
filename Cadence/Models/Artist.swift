import Foundation

struct Artist: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var albumIDs: [UUID]

    init(name: String, albumIDs: [UUID] = []) {
        self.id = name.lowercased()
        self.name = name
        self.albumIDs = albumIDs
    }
}
