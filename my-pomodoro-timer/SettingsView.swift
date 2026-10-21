import SwiftUI

struct SettingsView: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var settings: AppSettings
    var onStatistics: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label(settings.text(.settings), systemImage: "gearshape")
                .font(AppTypography.medium(24))

            VStack(alignment: .leading, spacing: 10) {
                settingRow(settings.text(.focusDuration)) {
                    SettingsPicker(selection: Binding(
                        get: { timer.selectedMinutes },
                        set: { timer.select(minutes: $0) }
                    ), options: PomodoroTimer.durations.map {
                        (value: $0, title: settings.text(.minutes, $0))
                    }, accessibilityLabel: settings.text(.focusDuration))
                    .disabled(timer.phase != .idle)
                }
                if timer.phase != .idle {
                    Text(settings.text(.durationLocked))
                        .font(AppTypography.regular(13))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
            settingRow(settings.text(.language)) {
                SettingsPicker(selection: Binding(
                    get: { AppLanguage.allCases.firstIndex(of: settings.language) ?? 0 },
                    set: { settings.language = AppLanguage.allCases[$0] }
                ), options: AppLanguage.allCases.enumerated().map { (value: $0.offset, title: $0.element.name) },
                   accessibilityLabel: settings.text(.language))
            }

            Divider()
            Button(action: onStatistics) {
                Label(settings.text(.statistics), systemImage: "chart.bar.xaxis")
                    .font(AppTypography.medium(16))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)

            Text(versionText)
                .font(AppTypography.regular(13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding(28)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.locale, settings.language.locale)
    }

    private func settingRow<Control: View>(_ title: String,
                                          @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 20) {
            Text(title)
                .font(AppTypography.regular(16))
                .fixedSize()
            Spacer(minLength: 0)
            control()
                .frame(width: 180, height: 28)
        }
        .frame(minHeight: 32)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        return settings.text(.version, version)
    }
}

// Explicit native fonts keep the selected value and menu items consistent.
private struct SettingsPicker: NSViewRepresentable {
    @Binding var selection: Int
    let options: [(value: Int, title: String)]
    let accessibilityLabel: String
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.controlSize = .large
        button.font = AppTypography.nativeFont(16)
        button.menu?.font = button.font
        for option in options {
            button.addItem(withTitle: option.title)
            button.lastItem?.tag = option.value
        }
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectDuration(_:))
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.selection = $selection
        for (item, option) in zip(button.itemArray, options) {
            item.title = option.title
            item.attributedTitle = AppTypography.nativeText(option.title, size: 16)
        }
        button.selectItem(withTag: selection)
        button.isEnabled = isEnabled
        button.setAccessibilityLabel(accessibilityLabel)
    }

    final class Coordinator: NSObject {
        var selection: Binding<Int>
        init(selection: Binding<Int>) { self.selection = selection }

        @objc func selectDuration(_ sender: NSPopUpButton) {
            guard let item = sender.selectedItem else { return }
            selection.wrappedValue = item.tag
        }
    }
}
