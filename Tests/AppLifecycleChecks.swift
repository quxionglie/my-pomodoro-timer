import AppKit
import SwiftUI

@main
struct AppLifecycleChecks {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        var now = Date()
        let timer = PomodoroTimer(now: { now }, automaticallyTicks: false)
        let delegate = AppDelegate(timer: timer)
        app.delegate = delegate

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            precondition(app.activationPolicy() == .accessory)
            guard let mainWindow = app.windows.first(where: { $0.title == "PomodoroTimer" }),
                  let controls = mainWindow.contentViewController as? NSHostingController<ContentView>
            else { fatalError("Initial controls window missing") }
            precondition(mainWindow.isVisible)
            capture(mainWindow, name: "controls")
            controls.rootView.onStatistics()
            guard let statisticsWindow = app.windows.first(where: { $0.title == "Statistics" }),
                  statisticsWindow.contentViewController is NSHostingController<StatisticsView>
            else { fatalError("Statistics window missing") }
            precondition(statisticsWindow.isVisible)
            capture(statisticsWindow, name: "statistics-empty")
            statisticsWindow.close()
            controls.rootView.onStart()
            precondition(timer.phase == .running && !mainWindow.isVisible)
            delegate.perform(NSSelectorFromString("togglePopover"))
            guard let menuWindow = app.windows.first(where: {
                $0 !== mainWindow && $0.isVisible && $0.frame.width >= 350 && $0.frame.height >= 500
            }) else { fatalError("Menu-bar controls did not open while running") }
            capture(menuWindow, name: "menu-controls")
            delegate.perform(NSSelectorFromString("togglePopover"))
            precondition(!menuWindow.isVisible)

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
                controls.rootView.onStatistics()
                precondition(statisticsWindow.isVisible)
                let renderer = ImageRenderer(content: StatisticsView(timer: timer)
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
                print("PASS: initial window, menu-bar-only policy, Start hides window, persistent floating reminder, close/Escape/quit guards, explicit dismissal, statistics window and live counts")
                app.terminate(nil)
            }
        }
        app.run()
        withExtendedLifetime(delegate) {}
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
