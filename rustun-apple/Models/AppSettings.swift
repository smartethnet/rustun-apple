import Foundation

enum AIModel: String, Codable, CaseIterable {
    case gpt = "gpt"
    case deepseek = "deepseek"
    
    var displayName: String {
        switch self {
        case .gpt: return "GPT"
        case .deepseek: return "DeepSeek"
        }
    }
}

struct AppSettings: Codable {
    var model: AIModel = .gpt
    var modelKey: String = ""
    
    private let settingsKey = "app_settings"
    
    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "app_settings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "app_settings")
        }
    }
}

