import Foundation

enum ConnectStep {
    case form
    case checking
    case success
}

enum ConnectAuthMethod: String, CaseIterable, Identifiable {
    case password
    case apiKey

    var id: String { rawValue }

    var label: String {
        switch self {
        case .password: return "Логин / Пароль"
        case .apiKey: return "API Key"
        }
    }
}
