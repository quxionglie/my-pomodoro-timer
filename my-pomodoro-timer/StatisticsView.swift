import SwiftUI
import UniformTypeIdentifiers

struct StatisticsView: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var settings: AppSettings
    @State private var exporting = false
    @State private var exportError: String?
    @State private var confirmingClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(settings.text(.statistics)).font(AppTypography.medium(24))
                Spacer()
                Button(settings.text(.exportMarkdown)) {
                    timer.refresh()
                    exporting = true
                }
                .disabled(timer.sessions.isEmpty)
            }
            Text(settings.text(.groupingHint))
                .font(AppTypography.regular(14))
                .foregroundStyle(.secondary)
            if timer.sessions.isEmpty {
                Spacer()
                Text(settings.text(.emptyStatistics))
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
                                    metric(settings.text(.starts), value: daily.starts)
                                    metric(settings.text(.manualStops), value: daily.stops)
                                    metric(settings.text(.completed), value: daily.completions)
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
                Button(settings.text(.clearAllMenu), role: .destructive) {
                    confirmingClear = true
                }
                .disabled(timer.sessions.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 260)
        .background(Color(nsColor: .windowBackgroundColor))
        .fileExporter(isPresented: $exporting,
                      document: MarkdownStatisticsDocument(text: DailyStatistics.markdown(timer.sessions)),
                      contentType: MarkdownStatisticsDocument.markdownType,
                      defaultFilename: "PomodoroTimer-Statistics.md") { result in
            if case .failure(let error) = result { exportError = error.localizedDescription }
        }
        .alert(settings.text(.exportFailed), isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button(settings.text(.ok)) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .alert(settings.text(.clearAllTitle), isPresented: $confirmingClear) {
            Button(settings.text(.cancel), role: .cancel) {}
            Button(settings.text(.clearAll), role: .destructive) { timer.clearStatistics() }
        } message: {
            Text(settings.text(.clearAllMessage))
        }
        .environment(\.locale, settings.language.locale)
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
