import Foundation

struct FocusSession: Codable, Identifiable {
    enum Status: String, Codable {
        case running, stopped, completed, interrupted

        var exportText: String {
            switch self {
            case .running: "In progress"
            case .stopped, .interrupted: "Terminated"
            case .completed: "Completed"
            }
        }
    }

    let id: UUID
    let startedAt: Date
    let day: String
    var status: Status
    var manualStoppedAt: Date?

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }
}

struct DailyStatistics: Identifiable {
    var id: String { day }
    let day: String
    let sessions: [FocusSession]
    var starts: Int { sessions.count }
    var stops: Int { sessions.filter { $0.status == .stopped }.count }
    var completions: Int { sessions.filter { $0.status == .completed }.count }

    static func grouped(_ sessions: [FocusSession]) -> [DailyStatistics] {
        Dictionary(grouping: sessions, by: \.day).map { day, records in
            DailyStatistics(day: day, sessions: records.sorted { $0.startedAt < $1.startedAt })
        }.sorted { $0.day > $1.day }
    }

    static func markdown(_ sessions: [FocusSession], timeZone: TimeZone = .current) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = timeZone
        return grouped(sessions).map { daily in
            var lines = ["# \(daily.day)", "",
                         "- Starts: \(daily.starts)",
                         "- Manual stops: \(daily.stops)",
                         "- Automatic completions: \(daily.completions)", ""]
            for session in daily.sessions {
                lines.append("- Start time: \(formatter.string(from: session.startedAt))")
                lines.append("  - Status: \(session.status.exportText)")
                lines.append("  - Manual stop time: \(session.manualStoppedAt.map { formatter.string(from: $0) } ?? "—")")
            }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n") + (sessions.isEmpty ? "" : "\n")
    }
}
