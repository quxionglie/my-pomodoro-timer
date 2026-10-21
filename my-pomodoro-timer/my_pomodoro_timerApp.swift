import SwiftUI

@main
struct PomodoroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            SettingsCommands(settings: appDelegate.settings, onSettings: appDelegate.showSettings)
        }
    }
}

private struct SettingsCommands: Commands {
    @ObservedObject var settings: AppSettings
    let onSettings: () -> Void

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(settings.text(.settingsMenu), action: onSettings)
                .keyboardShortcut(",", modifiers: .command)
        }
    }
}
