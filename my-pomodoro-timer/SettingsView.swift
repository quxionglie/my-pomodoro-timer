import SwiftUI

struct SettingsView: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var settings: AppSettings
    var onStatistics: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label(settings.text("Settings", "设置"), systemImage: "gearshape")
                .font(AppTypography.medium(24))

            VStack(alignment: .leading, spacing: 10) {
                settingRow(settings.text("Focus duration", "专注时长")) {
                    SettingsPicker(selection: Binding(
                        get: { timer.selectedMinutes },
                        set: { timer.select(minutes: $0) }
                    ), options: PomodoroTimer.durations.map {
                        (value: $0, title: settings.text("\($0) min", "\($0) 分钟"))
                    }, accessibilityLabel: settings.text("Focus duration", "专注时长"))
                    .disabled(timer.phase != .idle)
                }
                if timer.phase != .idle {
                    Text(settings.text("You can change the duration after this session ends.",
                                       "本轮计时结束并关闭提醒后，即可修改时长。"))
                        .font(AppTypography.regular(13))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
            settingRow(settings.text("Language", "语言")) {
                SettingsPicker(selection: Binding(
                    get: { settings.language == .english ? 0 : 1 },
                    set: { settings.language = $0 == 0 ? .english : .simplifiedChinese }
                ), options: [(value: 0, title: "English"), (value: 1, title: "简体中文")],
                   accessibilityLabel: settings.text("Language", "语言"))
            }

            Divider()
            Button(action: onStatistics) {
                Label(settings.text("Statistics", "统计"), systemImage: "chart.bar.xaxis")
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
        return settings.text("Version \(version)", "版本 \(version)")
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
