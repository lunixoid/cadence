import Foundation

enum JellyfinIdentity {
    static func itemID(from url: URL) -> String? {
        let components = url.pathComponents
        guard let audioIndex = components.firstIndex(of: "Audio"),
              audioIndex + 1 < components.count else {
            return nil
        }
        let candidate = components[audioIndex + 1]
        guard candidate != "universal" else { return nil }
        return candidate
    }
}
