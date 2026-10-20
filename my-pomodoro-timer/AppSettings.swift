import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }
    var name: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    func text(_ english: String, _ chinese: String) -> String {
        self == .english ? english : chinese
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            defaults?.set(language.rawValue, forKey: "appLanguage.v1")
            onChange?()
        }
    }
    var onChange: (() -> Void)?
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        language = defaults?.string(forKey: "appLanguage.v1")
            .flatMap(AppLanguage.init(rawValue:)) ?? .english
    }

    func text(_ english: String, _ chinese: String) -> String {
        language.text(english, chinese)
    }
}
