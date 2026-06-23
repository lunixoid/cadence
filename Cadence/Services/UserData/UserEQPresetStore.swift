import Foundation

struct UserEQPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var gains: [Double]

    init(id: UUID = UUID(), name: String, gains: [Double]) {
        self.id = id
        self.name = name
        self.gains = gains
    }
}

final class UserEQPresetStore {
    private let storageKey = "cadence.userEQPresets"

    func load() -> [UserEQPreset] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let presets = try? JSONDecoder().decode([UserEQPreset].self, from: data) else {
            return []
        }
        return presets
    }

    func save(_ presets: [UserEQPreset]) {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
