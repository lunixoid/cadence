import Foundation
import os.log

private let logger = Logger(subsystem: "dev.personal.cadence", category: "SavedFoldersStore")

struct SavedMusicFolder: Codable, Equatable, Identifiable {
    let id: UUID
    let bookmarkData: Data
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

        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

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

        for folder in folders {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: folder.bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                if isStale {
                    logger.warning("Stale bookmark for folder: \(folder.displayName)")
                }
                guard url.startAccessingSecurityScopedResource() else {
                    logger.error("Failed to access security-scoped resource: \(folder.displayName)")
                    continue
                }
                resolved.append((folder, url))
            } catch {
                logger.error("Failed to resolve bookmark for \(folder.displayName): \(error.localizedDescription)")
            }
        }

        return resolved
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
