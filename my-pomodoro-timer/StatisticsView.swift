import SwiftUI
import UniformTypeIdentifiers

struct StatisticsView: View {
    @ObservedObject var timer: PomodoroTimer
    @State private var exporting = false
    @State private var exportError: String?
    @State private var confirmingClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Statistics").font(AppTypography.medium(24))
                Spacer()
                Button("Export Markdown…") {
                    timer.refresh()
                    exporting = true
                }
                .disabled(timer.sessions.isEmpty)
            }
            Text("Sessions are grouped by their local start date.")
                .font(AppTypography.regular(14))
                .foregroundStyle(.secondary)
            if timer.sessions.isEmpty {
                Spacer()
                Text("No sessions yet. Start a timer to see your statistics.")
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(DailyStatistics.grouped(timer.sessions)) { daily in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(daily.day).font(AppTypography.medium(18))
                                HStack {
                                    metric("Starts", value: daily.starts)
                                    metric("Manual stops", value: daily.stops)
                                    metric("Completed", value: daily.completions)
                                }
                                Divider()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            HStack {
                Spacer()
                Button("Clear All…", role: .destructive) {
                    confirmingClear = true
                }
                .disabled(timer.sessions.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 260)
        .fileExporter(isPresented: $exporting,
                      document: MarkdownStatisticsDocument(text: DailyStatistics.markdown(timer.sessions)),
                      contentType: MarkdownStatisticsDocument.markdownType,
                      defaultFilename: "PomodoroTimer-Statistics.md") { result in
            if case .failure(let error) = result { exportError = error.localizedDescription }
        }
        .alert("Export failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .alert("Clear all statistics?", isPresented: $confirmingClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) { timer.clearStatistics() }
        } message: {
            Text("All saved statistics, including the current session record, will be permanently deleted. A running timer will continue, but its session will no longer be recorded.")
        }
    }

    private func metric(_ title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(AppTypography.regular(14)).foregroundStyle(.secondary)
            Text("\(value)").font(AppTypography.medium(24)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MarkdownStatisticsDocument: FileDocument {
    static let markdownType = UTType(filenameExtension: "md") ?? .plainText
    static var readableContentTypes: [UTType] { [markdownType] }
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
