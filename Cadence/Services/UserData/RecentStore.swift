import Foundation

@Observable
final class RecentStore {
    private let maxCount = 50
    private let storageKey = "cadence.recentTrackIDs"

    private(set) var recentTrackIDs: [UUID] = []

    init() {
        load()
    }

    func record(track: Track) {
        recentTrackIDs.removeAll { $0 == track.id }
        recentTrackIDs.insert(track.id, at: 0)
        if recentTrackIDs.count > maxCount {
            recentTrackIDs = Array(recentTrackIDs.prefix(maxCount))
        }
        save()
    }

    func tracks(from library: LibraryStore) -> [Track] {
        recentTrackIDs.compactMap { library.track(for: $0) }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let ids = try? JSONDecoder().decode([UUID].self, from: data) {
            recentTrackIDs = ids
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(recentTrackIDs) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
