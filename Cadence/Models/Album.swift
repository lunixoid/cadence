import SwiftUI

struct Album: Identifiable, Equatable {
    let id: UUID
    var title: String
    var artist: String
    var year: Int?
    var accentColors: [Color]
    var coverURL: URL?
    var folderURL: URL?

    init(
        id: UUID = UUID(),
        title: String = "",
        artist: String = "",
        year: Int? = nil,
        accentColors: [Color] = CadenceTheme.placeholderGradientColors,
        coverURL: URL? = nil,
        folderURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.year = year
        self.accentColors = accentColors
        self.coverURL = coverURL
        self.folderURL = folderURL
    }
}
