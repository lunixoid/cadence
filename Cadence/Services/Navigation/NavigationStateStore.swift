import Foundation

struct NavigationStateSnapshot: Codable, Equatable {
    var activeSidebarItem: SidebarItem
    var contentRoute: ContentRoute
    var navigationStack: [ContentRoute]
    var forwardStack: [ContentRoute]
}

@MainActor
final class NavigationStateStore {
    private let storageKey = "cadence.navigationState"

    func save(_ snapshot: NavigationStateSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func load() -> NavigationStateSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(NavigationStateSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }
}
