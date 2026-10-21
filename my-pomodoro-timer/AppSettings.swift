import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    var id: String { rawValue }
    var name: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }
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

    func text(_ key: AppText, _ arguments: CVarArg...) -> String {
        language.localizedText(key, arguments: arguments)
    }
}
