import Combine
import Foundation

@MainActor
final class PomodoroTimer: ObservableObject {
    static let durations = [15, 30, 45, 60, 90]

    enum Phase {
        case idle, running, finished
    }

    @Published private(set) var selectedMinutes = 30
    @Published private(set) var remainingSeconds = 30 * 60
    @Published private(set) var phase: Phase = .idle

    @Published private(set) var sessions: [FocusSession] = []
    private let defaults: UserDefaults?
    private let historyKey = "focusSessionHistory.v1"

    var onChange: (() -> Void)?
    var onFinish: (() -> Void)?

    private var deadline: Date?
    private var ticker: Timer?
    private var activity: NSObjectProtocol?
    private let now: () -> Date
    private let automaticallyTicks: Bool

    init(now: @escaping () -> Date = Date.init, automaticallyTicks: Bool = true,
         defaults: UserDefaults? = nil) {
        self.defaults = defaults
        self.now = now
        self.automaticallyTicks = automaticallyTicks
        if let saved = defaults?.object(forKey: "focusDurationMinutes.v1") as? Int,
           Self.durations.contains(saved) {
            selectedMinutes = saved
            remainingSeconds = saved * 60
        }
        if let data = defaults?.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode([FocusSession].self, from: data) {
            sessions = saved
            // A previous process cannot resume its countdown.
            for index in sessions.indices where sessions[index].status == .running {
                sessions[index].status = .interrupted
            }
            saveHistory()
        }
    }

    var timeText: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    var progress: Double {
        1 - Double(remainingSeconds) / Double(selectedMinutes * 60)
    }

    func select(minutes: Int) {
        guard phase == .idle, Self.durations.contains(minutes) else { return }
        selectedMinutes = minutes
        remainingSeconds = minutes * 60
        defaults?.set(minutes, forKey: "focusDurationMinutes.v1")
        onChange?()
    }

    func start() {
        guard phase == .idle else { return }
        remainingSeconds = selectedMinutes * 60
        let startedAt = now()
        deadline = startedAt.addingTimeInterval(TimeInterval(remainingSeconds))
        sessions.append(FocusSession(id: UUID(), startedAt: startedAt,
                                     day: FocusSession.dayKey(for: startedAt), status: .running))
        saveHistory()
        phase = .running
        if automaticallyTicks {
            activity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Pomodoro countdown"
            )
            let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
            timer.tolerance = 0.05
            RunLoop.main.add(timer, forMode: .common)
            ticker = timer
        }
        onChange?()
    }

    func stop() {
        refresh()
        guard phase == .running else { return }
        finishSession(status: .stopped, stoppedAt: now())
        reset()
    }

    func dismissReminder() {
        guard phase == .finished else { return }
        reset()
    }

    // Compare against the deadline instead of counting ticks, including after sleep.
    func refresh() {
        guard phase == .running, let deadline else { return }
        let seconds = max(0, Int(ceil(deadline.timeIntervalSince(now()))))
        if seconds != remainingSeconds { remainingSeconds = seconds }
        if seconds == 0 {
            finishSession(status: .completed)
            invalidateTicker()
            self.deadline = nil
            phase = .finished
            onChange?()
            onFinish?()
        } else {
            onChange?()
        }
    }

    func interruptForQuit() {
        guard phase == .running else { return }
        finishSession(status: .interrupted)
        reset()
    }

    func clearStatistics() {
        sessions.removeAll()
        saveHistory()
    }

    private func finishSession(status: FocusSession.Status, stoppedAt: Date? = nil) {
        guard let index = sessions.lastIndex(where: { $0.status == .running }) else { return }
        sessions[index].status = status
        sessions[index].manualStoppedAt = stoppedAt
        saveHistory()
    }

    private func saveHistory() {
        guard let defaults, let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: historyKey)
    }

    private func reset() {
        invalidateTicker()
        deadline = nil
        remainingSeconds = selectedMinutes * 60
        phase = .idle
        onChange?()
    }

    private func invalidateTicker() {
        ticker?.invalidate()
        ticker = nil
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }
}
