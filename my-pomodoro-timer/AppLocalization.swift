import Foundation

// Translation values live in each language's Localizable.strings resource.
enum AppText: String, CaseIterable {
    case settings
    case focusDuration
    case minutes
    case durationLocked
    case language
    case statistics
    case version
    case timesUp
    case runningHint
    case startHint
    case quit
    case ready
    case focusing
    case takeBreak
    case start
    case stop
    case showReminder
    case breakTitle
    case completedFocus
    case dismissReminder
    case reminderHint
    case exportMarkdown
    case groupingHint
    case emptyStatistics
    case starts
    case manualStops
    case completed
    case clearAllMenu
    case exportFailed
    case ok
    case cancel
    case clearAllTitle
    case clearAll
    case clearAllMessage
    case settingsMenu
    case sessionComplete
    case idleTooltip
    case runningTooltip
    case timesUpStatus
    case reminderTooltip
    case progressDescription
}

extension AppLanguage {
    func localizedText(_ key: AppText, arguments: [CVarArg]) -> String {
        let fallback = translationBundle(for: "en")?.localizedString(
            forKey: key.rawValue, value: key.rawValue, table: nil
        ) ?? key.rawValue
        let format = translationBundle(for: rawValue)?.localizedString(
            forKey: key.rawValue, value: fallback, table: nil
        ) ?? fallback
        return String(format: format, locale: locale, arguments: arguments)
    }

    private func translationBundle(for language: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
}
