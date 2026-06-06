import CryptoKit
import Foundation

enum StableIdentity {
    static func trackID(for fileURL: URL) -> UUID {
        stableUUID(from: "track:" + fileURL.standardizedFileURL.path)
    }

    static func albumID(sourceFolderPath: String, title: String, artist: String) -> UUID {
        stableUUID(from: "album:\(sourceFolderPath)|\(title)|\(artist)")
    }

    static func jellyfinItemID(_ itemID: String) -> UUID {
        stableUUID(from: "jellyfin:\(itemID)")
    }

    private static func stableUUID(from string: String) -> UUID {
        let hash = SHA256.hash(data: Data(string.utf8))
        let bytes = Array(hash.prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
