import Foundation

enum EQBand: String, CaseIterable, Identifiable {
    case hz32 = "32"
    case hz64 = "64"
    case hz125 = "125"
    case hz250 = "250"
    case hz500 = "500"
    case k1 = "1K"
    case k2 = "2K"
    case k4 = "4K"
    case k8 = "8K"
    case k16 = "16K"

    var id: String { rawValue }
}

// Пресеты заточены под Sony WH-1000XM5 (V-образная АЧХ с завышенным басом
// и просевшей серединой). Принцип: саб-рамбл оставляем, бубнящий бас 125–250 Hz
// поджимаем, просевшую середину заполняем, presence/воздух добавляем аккуратно.
// Максимальный буст ограничен +5 dB — остальное добирается срезами и преампом
// (AudioEngineService.globalGain), поэтому сигнал не клиппует и не дребезжит.
// Бэнды: 32 · 64 · 125 · 250 · 500 · 1K · 2K · 4K · 8K · 16K
enum EQPreset: String, CaseIterable, Identifiable {
    case flat = "Flat"
    case signature = "Signature"
    case bass = "Bass"
    case heavyMetal = "Heavy Metal"
    case alternative = "Alternative / Rock"
    case animeOST = "Anime OST"
    case jazz = "Jazz"
    case pop = "Pop"
    case classical = "Classical"
    case electronic = "Electronic"
    case hipHop = "Hip-Hop"
    case acoustic = "Acoustic"
    case vocal = "Vocal"
    case custom = "Custom"

    var id: String { rawValue }

    var gains: [Double] {
        switch self {
        case .flat:        return Array(repeating: 0, count: 10)
        case .signature:   return [3, 4, 0, -1, 0, 1, 2, 2, 3, 3]
        case .bass:        return [5, 5, 2, -1, -1, 0, 0, 1, 2, 2]
        case .heavyMetal:  return [4, 4, 1, 0, 1, 1, 3, 3, 4, 2]
        case .alternative: return [3, 3, 1, 0, 0, 1, 2, 2, 3, 3]
        case .animeOST:    return [2, 3, 0, 0, 1, 2, 3, 2, 3, 4]
        case .jazz:        return [3, 3, 1, 0, 1, 1, 0, 1, 2, 2]
        case .pop:         return [2, 2, 1, 0, 1, 1, 1, 1, 2, 2]
        case .classical:   return [2, 2, 1, 0, 0, 0, 0, 1, 2, 2]
        case .electronic:  return [5, 4, 2, 0, -1, 0, 1, 2, 3, 4]
        case .hipHop:      return [5, 5, 2, 0, -1, 0, 0, 1, 1, 1]
        case .acoustic:    return [2, 2, 1, 1, 1, 1, 1, 1, 2, 2]
        case .vocal:       return [-1, 0, 0, 1, 2, 3, 3, 2, 1, 0]
        case .custom:      return Array(repeating: 0, count: 10)
        }
    }

    static func matching(gains: [Double]) -> EQPreset {
        allCases.first { $0 != .custom && $0.gains == gains } ?? .custom
    }
}
