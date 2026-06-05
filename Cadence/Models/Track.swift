import Foundation

struct Track: Identifiable, Equatable, Hashable {
    let id: UUID
    var index: Int
    var title: String
    var artist: String
    var albumID: UUID
    var duration: TimeInterval
    var fileURL: URL
    var discNumber: Int

    init(
        id: UUID = UUID(),
        index: Int,
        title: String = "",
        artist: String = "",
        albumID: UUID,
        duration: TimeInterval = 0,
        fileURL: URL,
        discNumber: Int = 1
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.artist = artist
        self.albumID = albumID
        self.duration = duration
        self.fileURL = fileURL
        self.discNumber = discNumber
    }
}
