import Foundation
import os.log

private let logger = Logger(subsystem: "dev.personal.cadence", category: "SavedFoldersStore")

struct SavedMusicFolder: Codable, Equatable, Identifiable {
    let id: UUID
    var bookmarkData: Data
    let standardizedPath: String
    let displayName: String
}

final class SavedFoldersStore {
    private let storageKey = "cadence.savedMusicFolders"

    private(set) var folders: [SavedMusicFolder] = []

    init() {
        load()
    }

    func contains(path: String) -> Bool {
        folders.contains { $0.standardizedPath == path }
    }

    func add(url: URL) throws {
        let path = url.standardizedFileURL.path
        guard !contains(path: path) else { return }

        let bookmarkData = try Self.makeBookmark(for: url)

        let folder = SavedMusicFolder(
            id: UUID(),
            bookmarkData: bookmarkData,
            standardizedPath: path,
            displayName: url.lastPathComponent
        )
        folders.append(folder)
        save()
    }

    func resolveAll() -> [(SavedMusicFolder, URL)] {
        var resolved: [(SavedMusicFolder, URL)] = []
        var didRefreshBookmarks = false

        for index in folders.indices {
            let folder = folders[index]
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: folder.bookmarkData,
                    options: {
                        #if os(macOS)
                        return .withSecurityScope
                        #else
                        return []
                        #endif
                    }(),
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                guard url.startAccessingSecurityScopedResource() else {
                    logger.error("Failed to access security-scoped resource: \(folder.displayName)")
                    if let fallback = resolveByPath(at: index) {
                        resolved.append(fallback)
                        didRefreshBookmarks = true
                    }
                    continue
                }
                if isStale, let refreshed = try? Self.makeBookmark(for: url) {
                    logger.info("Refreshed stale bookmark for folder: \(folder.displayName)")
                    folders[index].bookmarkData = refreshed
                    didRefreshBookmarks = true
                }
                resolved.append((folders[index], url))
            } catch {
                logger.error("Failed to resolve bookmark for \(folder.displayName): \(error.localizedDescription)")
                if let fallback = resolveByPath(at: index) {
                    resolved.append(fallback)
                    didRefreshBookmarks = true
                }
            }
        }

        if didRefreshBookmarks {
            save()
        }
        return resolved
    }

    /// Bookmarks are bound to the app's code signature, so a re-signed build can't resolve
    /// them. Folders the sandbox can still read (Downloads, Music) are reopened by path
    /// and get a fresh bookmark.
    private func resolveByPath(at index: Int) -> (SavedMusicFolder, URL)? {
        let folder = folders[index]
        let url = URL(fileURLWithPath: folder.standardizedPath, isDirectory: true)
        do {
            // Listing (unlike access(2)) lets macOS ask for Downloads/Music folder consent.
            _ = try FileManager.default.contentsOfDirectory(atPath: url.path)
        } catch {
            logger.error("Folder not readable by path: \(folder.displayName): \(error.localizedDescription)")
            return nil
        }
        if let refreshed = try? Self.makeBookmark(for: url) {
            folders[index].bookmarkData = refreshed
        }
        logger.info("Recovered folder by path: \(folder.displayName)")
        return (folders[index], url)
    }

    private static func makeBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: {
                #if os(macOS)
                return .withSecurityScope
                #else
                return []
                #endif
            }(),
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SavedMusicFolder].self, from: data) else {
            return
        }
        folders = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
