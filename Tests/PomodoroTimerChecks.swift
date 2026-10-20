import Foundation

@main
struct PomodoroTimerChecks {
    @MainActor
    static func main() {
        var now = Date(timeIntervalSince1970: 1_000_000)
        let timer = PomodoroTimer(now: { now }, automaticallyTicks: false)
        var reminders = 0
        timer.onFinish = { reminders += 1 }

        precondition(timer.selectedMinutes == 30 && timer.timeText == "30:00")
        precondition(PomodoroTimer.durations == [15, 30, 45, 60, 90])
        for duration in PomodoroTimer.durations {
            timer.select(minutes: duration)
            timer.start()
            precondition(timer.remainingSeconds == duration * 60)
            timer.stop()
        }
        timer.select(minutes: 7)
        precondition(timer.selectedMinutes == 90)
        precondition(timer.timeText == "90:00")

        timer.select(minutes: 15)
        timer.start()
        now.addTimeInterval(0.1)
        timer.refresh()
        precondition(timer.timeText == "15:00", "Do not drop a second immediately on start")
        now.addTimeInterval(0.9)
        timer.refresh()
        precondition(timer.timeText == "14:59")
        timer.select(minutes: 60)
        timer.start()
        precondition(timer.selectedMinutes == 15 && timer.remainingSeconds == 899)

        now.addTimeInterval(898.5)
        timer.refresh()
        precondition(timer.phase == .running && timer.remainingSeconds == 1)
        now.addTimeInterval(0.5)
        timer.refresh()
        precondition(timer.phase == .finished && timer.remainingSeconds == 0 && reminders == 1)
        precondition(timer.progress == 1)
        timer.refresh()
        timer.stop()
        timer.start()
        timer.select(minutes: 90)
        precondition(timer.phase == .finished && reminders == 1 && timer.selectedMinutes == 15,
                     "Completion must persist until explicitly acknowledged")
        timer.dismissReminder()
        precondition(timer.phase == .idle && timer.timeText == "15:00")

        timer.start()
        now.addTimeInterval(10)
        timer.stop()
        now.addTimeInterval(2000)
        timer.refresh()
        precondition(timer.phase == .idle && reminders == 1, "Stopped timers must not alert")

        timer.select(minutes: 30)
        timer.start()
        now.addTimeInterval(7200)
        timer.refresh()
        precondition(timer.phase == .finished && reminders == 2,
                     "Wake after deadline must finish immediately, exactly once")
        timer.refresh()
        precondition(reminders == 2)
        checkStatistics()
        checkSettings()
        print("PASS: defaults, all durations, invalid selection, rounding, duplicate start, expiry, persistent reminder, Stop, restart, wake after deadline")
    }

    @MainActor
    private static func checkSettings() {
        let suite = "PomodoroSettingsChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        precondition(settings.language == .english)
        settings.language = .simplifiedChinese
        precondition(AppSettings(defaults: defaults).language == .simplifiedChinese)
        precondition(settings.text("Settings", "设置") == "设置")
        settings.language = .english
        precondition(AppSettings(defaults: defaults).language == .english)
        defaults.set("unsupported-language", forKey: "appLanguage.v1")
        precondition(AppSettings(defaults: defaults).language == .english)

        let timer = PomodoroTimer(automaticallyTicks: false, defaults: defaults)
        timer.select(minutes: 45)
        let restored = PomodoroTimer(automaticallyTicks: false, defaults: defaults)
        precondition(restored.selectedMinutes == 45 && restored.timeText == "45:00")
        restored.start()
        restored.select(minutes: 90)
        settings.language = .simplifiedChinese
        precondition(restored.selectedMinutes == 45 && restored.phase == .running)
        precondition(PomodoroTimer(automaticallyTicks: false, defaults: defaults).selectedMinutes == 45)
        defaults.set(7, forKey: "focusDurationMinutes.v1")
        let fallback = PomodoroTimer(automaticallyTicks: false, defaults: defaults)
        precondition(fallback.selectedMinutes == 30 && fallback.timeText == "30:00")
        print("PASS: language and duration persistence, unsupported values, language change during timer, locked duration")
    }

    @MainActor
    private static func checkStatistics() {
        let suite = "PomodoroTimerChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let iso = ISO8601DateFormatter()
        var now = iso.date(from: "2026-10-20T15:59:00Z")!
        let timer = PomodoroTimer(now: { now }, automaticallyTicks: false, defaults: defaults)
        precondition(timer.sessions.isEmpty && DailyStatistics.grouped(timer.sessions).isEmpty)
        precondition(DailyStatistics.markdown([]).isEmpty)
        timer.select(minutes: 15)
        timer.start()
        timer.start()
        precondition(timer.sessions.count == 1, "Duplicate Start must not add a record")
        let firstDay = timer.sessions[0].day
        now.addTimeInterval(120)
        timer.stop()
        timer.stop()
        precondition(timer.sessions[0].status == .stopped)
        precondition(timer.sessions[0].manualStoppedAt == now)
        precondition(timer.sessions[0].day == firstDay, "Cross-midnight sessions belong to their start day")
        timer.start()
        now.addTimeInterval(900)
        // Stop after the deadline must be recorded as automatic completion.
        timer.stop()
        timer.refresh()
        timer.dismissReminder()
        timer.dismissReminder()
        precondition(timer.sessions.count == 2 && timer.sessions[1].status == .completed)
        precondition(timer.sessions[1].manualStoppedAt == nil)
        let days = DailyStatistics.grouped(timer.sessions)
        precondition(days.reduce(0) { $0 + $1.starts } == 2)
        precondition(days.reduce(0) { $0 + $1.stops } == 1)
        precondition(days.reduce(0) { $0 + $1.completions } == 1)
        let md = DailyStatistics.markdown(timer.sessions, timeZone: TimeZone(secondsFromGMT: 8 * 3600)!)
        precondition(md.contains("# \(firstDay)"))
        precondition(md.contains("Start time: 2026-10-20T23:59:00+08:00"))
        precondition(md.contains("Manual stop time: 2026-10-21T00:01:00+08:00"))
        precondition(md.contains("Status: Terminated") && md.contains("Status: Completed"))
        precondition(md.contains("Manual stop time: —"))
        let western = DailyStatistics.markdown(timer.sessions, timeZone: TimeZone(secondsFromGMT: -7 * 3600)!)
        precondition(western.contains("Start time: 2026-10-20T08:59:00-07:00"))
        precondition(DailyStatistics.markdown(timer.sessions) ==
                     DailyStatistics.markdown(timer.sessions, timeZone: .current))
        timer.start()
        precondition(DailyStatistics.markdown(timer.sessions).contains("Status: In progress"))
        let restored = PomodoroTimer(now: { now }, automaticallyTicks: false, defaults: defaults)
        precondition(restored.sessions.count == 3 && restored.sessions[2].status == .interrupted)
        precondition(restored.sessions[2].manualStoppedAt == nil && restored.phase == .idle)
        restored.start()
        restored.interruptForQuit()
        let reloaded = PomodoroTimer(automaticallyTicks: false, defaults: defaults)
        precondition(reloaded.sessions.count == 4 && reloaded.sessions[3].status == .interrupted)
        precondition(DailyStatistics.grouped(reloaded.sessions).reduce(0) { $0 + $1.stops } == 1)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        precondition(FocusSession.dayKey(for: iso.date(from: "2026-10-20T15:59:00Z")!, calendar: calendar) == "2026-10-20")
        precondition(FocusSession.dayKey(for: iso.date(from: "2026-10-20T16:01:00Z")!, calendar: calendar) == "2026-10-21")
        let separateDays = [
            FocusSession(id: UUID(), startedAt: now, day: "2026-10-20", status: .stopped),
            FocusSession(id: UUID(), startedAt: now, day: "2026-10-21", status: .completed)
        ]
        precondition(DailyStatistics.grouped(separateDays).map(\.day) == ["2026-10-21", "2026-10-20"])
        reloaded.clearStatistics()
        precondition(reloaded.sessions.isEmpty && DailyStatistics.markdown(reloaded.sessions).isEmpty)
        let cleared = PomodoroTimer(now: { now }, automaticallyTicks: false, defaults: defaults)
        precondition(cleared.sessions.isEmpty, "Cleared statistics must stay empty after relaunch")
        cleared.start()
        now.addTimeInterval(60)
        cleared.refresh()
        let remaining = cleared.remainingSeconds
        cleared.clearStatistics()
        precondition(cleared.phase == .running && cleared.remainingSeconds == remaining)
        cleared.stop()
        precondition(cleared.sessions.isEmpty, "Stop must not recreate a cleared record")
        cleared.start()
        cleared.clearStatistics()
        now.addTimeInterval(1800)
        cleared.refresh()
        precondition(cleared.phase == .finished && cleared.sessions.isEmpty,
                     "Completion must not recreate a cleared record")
        cleared.dismissReminder()
        cleared.start()
        cleared.stop()
        precondition(cleared.sessions.count == 1 && cleared.sessions[0].status == .stopped,
                     "New sessions must be recorded after clearing")
        cleared.clearStatistics()
        cleared.clearStatistics()
        precondition(PomodoroTimer(automaticallyTicks: false, defaults: defaults).sessions.isEmpty)
        print("PASS: clear all statistics, persistence, clear while running, stop/completion after clear, recording new sessions")
        print("PASS: daily counts, empty days, duplicate actions, cross-midnight dates, deadline Stop, local-time Markdown, persistence, running and interrupted sessions")
    }

}
