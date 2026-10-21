import AppKit
import SwiftUI

@main
struct AppLifecycleChecks {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        var now = Date()
        let timer = PomodoroTimer(now: { now }, automaticallyTicks: false)
        let settings = AppSettings()
        let delegate = AppDelegate(timer: timer, settings: settings)
        app.delegate = delegate

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            precondition(app.activationPolicy() == .accessory)
            guard let mainWindow = app.windows.first(where: { $0.title == "PomodoroTimer" }),
                  let controls = mainWindow.contentViewController as? NSHostingController<ContentView>
            else { fatalError("Initial controls window missing") }
            precondition(mainWindow.isVisible)
            precondition(durationPicker(in: mainWindow.contentView!) == nil,
                         "Home must not contain a duration picker")
            capture(mainWindow, name: "controls")
            controls.rootView.onSettings()
            guard let settingsWindow = app.windows.first(where: { $0.title == "Settings" }),
                  let settingsController = settingsWindow.contentViewController as? NSHostingController<SettingsView>
            else { fatalError("Settings window missing") }
            capture(settingsWindow, name: "settings")
            guard let picker = durationPicker(in: settingsWindow.contentView!) else {
                fatalError("Duration picker missing from settings")
            }
            precondition(picker.itemArray.map(\.tag) == PomodoroTimer.durations)
            // Drive the same target/action as an actual menu selection.
            picker.selectItem(withTag: 45)
            _ = picker.target?.perform(picker.action, with: picker)
            precondition(timer.selectedMinutes == 45 && timer.timeText == "45:00")
            timer.select(minutes: 30)
            settingsController.rootView.onStatistics()
            guard let statisticsWindow = app.windows.first(where: { $0.title == "Statistics" }),
                  statisticsWindow.contentViewController is NSHostingController<StatisticsView>
            else { fatalError("Statistics window missing") }
            precondition(statisticsWindow.isVisible)
            capture(statisticsWindow, name: "statistics-empty")
            settings.language = .simplifiedChinese
            precondition(settingsWindow.title == "设置" && statisticsWindow.title == "统计")
            capture(settingsWindow, name: "settings-zh")
            precondition(picker.selectedItem?.title == "30 分钟")
            capture(mainWindow, name: "controls-zh")
            capture(statisticsWindow, name: "statistics-empty-zh")
            settings.language = .traditionalChinese
            capture(settingsWindow, name: "settings-zh-Hant")
            precondition(settingsWindow.title == "設定" && statisticsWindow.title == "統計")
            precondition(picker.selectedItem?.title == "30 分鐘")
            guard let languageControl = settingsWindow.contentView.flatMap({ languagePicker(in: $0) }) else {
                fatalError("Language picker missing")
            }
            precondition(languageControl.itemTitles == ["English", "简体中文", "繁體中文"])
            precondition(languageControl.selectedItem?.tag == 2)
            capture(mainWindow, name: "controls-zh-Hant")
            capture(statisticsWindow, name: "statistics-empty-zh-Hant")
            languageControl.selectItem(withTag: 0)
            _ = languageControl.target?.perform(languageControl.action, with: languageControl)
            precondition(settings.language == .english && settingsWindow.title == "Settings")
            settingsWindow.close()
            statisticsWindow.close()
            controls.rootView.onStart()
            precondition(timer.phase == .running && !mainWindow.isVisible)
            delegate.perform(NSSelectorFromString("togglePopover"))
            guard let menuWindow = app.windows.first(where: {
                $0 !== mainWindow && $0.isVisible && $0.contentViewController is NSHostingController<ContentView>
            }) else { fatalError("Menu-bar controls did not open while running") }
            capture(menuWindow, name: "menu-controls")
            delegate.perform(NSSelectorFromString("togglePopover"))
            precondition(!menuWindow.isVisible)
            controls.rootView.onSettings()
            capture(settingsWindow, name: "settings-running")
            precondition(!picker.isEnabled, "Duration must be locked while running")
            settings.language = .simplifiedChinese
            precondition(timer.phase == .running && timer.remainingSeconds == 1800)
            settings.language = .english
            settingsWindow.close()

            now.addTimeInterval(1801)
            timer.refresh()
            guard let panel = app.windows.first(where: { $0.title == "Session complete" }) as? NSPanel,
                  let reminder = panel.contentViewController as? NSHostingController<ReminderView>
            else { fatalError("Completion reminder missing") }
            precondition(panel.isVisible && !panel.hidesOnDeactivate)
            precondition(panel.level == .modalPanel)
            precondition(!panel.styleMask.contains(.closable))
            precondition(!panel.styleMask.contains(.miniaturizable))
            precondition(panel.collectionBehavior.contains(.canJoinAllSpaces))
            capture(panel, name: "reminder")
            settings.language = .simplifiedChinese
            precondition(panel.title == "本轮已完成")
            capture(panel, name: "reminder-zh")
            settings.language = .traditionalChinese
            precondition(panel.title == "本輪已完成")
            capture(panel, name: "reminder-zh-Hant")
            settings.language = .english
            panel.performClose(nil)
            panel.cancelOperation(nil)
            precondition(panel.isVisible && timer.phase == .finished)
            precondition(!delegate.windowShouldClose(panel))
            precondition(delegate.applicationShouldTerminate(app) == .terminateCancel)

            // Switching focus must not dismiss the reminder.
            app.deactivate()
            app.hide(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                precondition(panel.isVisible && timer.phase == .finished)
                reminder.rootView.onDismiss()
                precondition(!panel.isVisible && timer.phase == .idle)
                timer.start()
                now.addTimeInterval(60)
                timer.stop()
                settingsController.rootView.onStatistics()
                precondition(statisticsWindow.isVisible)
                let renderer = ImageRenderer(content: StatisticsView(timer: timer, settings: settings)
                    .frame(width: 600, height: 480)
                    .background(Color(nsColor: .windowBackgroundColor)))
                renderer.scale = 2
                guard let image = renderer.cgImage,
                      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
                else { fatalError("Unable to render statistics preview") }
                try! png.write(to: URL(fileURLWithPath: "build/statistics.png"))
                let daily = DailyStatistics.grouped(timer.sessions)
                precondition(daily.reduce(0) { $0 + $1.starts } == 2)
                precondition(daily.reduce(0) { $0 + $1.stops } == 1)
                precondition(daily.reduce(0) { $0 + $1.completions } == 1)
                try! DailyStatistics.markdown(timer.sessions).write(
                    toFile: "build/statistics-example.md", atomically: true, encoding: .utf8
                )
                precondition(delegate.applicationShouldTerminate(app) == .terminateNow)
                print("PASS: settings entry, duration selection and locking, live trilingual windows, initial window, menu-bar controls, persistent reminder, quit guards, statistics and live counts")
                app.terminate(nil)
            }
        }
        app.run()
        withExtendedLifetime(delegate) {}
    }

    @MainActor
    private static func languagePicker(in view: NSView) -> NSPopUpButton? {
        if let picker = view as? NSPopUpButton, picker.itemTitles.contains("繁體中文") { return picker }
        for child in view.subviews {
            if let picker = languagePicker(in: child) { return picker }
        }
        return nil
    }

    @MainActor
    private static func durationPicker(in view: NSView) -> NSPopUpButton? {
        if let picker = view as? NSPopUpButton { return picker }
        for child in view.subviews {
            if let picker = durationPicker(in: child) { return picker }
        }
        return nil
    }

    @MainActor
    private static func capture(_ window: NSWindow, name: String) {
        // Allow the newly presented SwiftUI hierarchy to render before capture.
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        guard let view = window.contentView else { fatalError("Missing content view") }
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            fatalError("Unable to capture view")
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Unable to encode preview")
        }
        try! data.write(to: URL(fileURLWithPath: "build/\(name).png"))
    }
}
