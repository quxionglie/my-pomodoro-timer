import SwiftUI

struct ContentView: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var settings: AppSettings
    var onStart: () -> Void
    var onShowReminder: () -> Void
    var onSettings: () -> Void
    var onQuit: () -> Void

    private let accent = Color(red: 0.87, green: 0.29, blue: 0.22)

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("PomodoroTimer").font(AppTypography.medium(20))
                }
                Spacer()
                Circle()
                    .fill(timer.phase == .running ? Color.green : accent.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }

            ZStack {
                Circle().stroke(accent.opacity(0.1), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: timer.phase == .idle ? 1 : timer.progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 8) {
                    Text(timer.phase == .finished ? settings.text("Time’s up", "时间到") : timer.timeText)
                        .font(timer.phase == .finished
                              ? AppTypography.medium(42)
                              : AppTypography.latin(50))
                        .monospacedDigit()
                    Text(statusText)
                        .font(AppTypography.regular(17))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 240, height: 240)
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)

            Button(action: primaryAction) {
                Label {
                    AppTypography.text(buttonTitle, size: 19, emphasized: true)
                } icon: {
                    Image(systemName: buttonIcon)
                        .font(.system(size: 19, weight: .semibold))
                }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .controlSize(.large)

            AppTypography.text(timer.phase == .running
                 ? settings.text("Timer is running in the background.\nClick Stop to end your session.", "计时正在后台进行。\n点击停止即可结束本轮专注。")
                 : settings.text("Start to continue in the menu bar.\nDismiss the reminder when time is up.", "开始后将在菜单栏继续计时。\n时间到后，请手动关闭提醒。"), size: 14)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
            HStack {
                Button(action: onSettings) {
                    Label(settings.text("Settings", "设置"), systemImage: "gearshape")
                        .labelStyle(.iconOnly)
                        .font(AppTypography.medium(14))
                }
                .buttonStyle(.plain)
                .help(settings.text("Settings", "设置"))
                .foregroundStyle(.secondary)
                Spacer()
                Button(action: onQuit) {
                    Text(settings.text("Quit", "退出")).font(AppTypography.medium(14))
                }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(width: 390)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.locale, settings.language.locale)
    }

    private var statusText: String {
        switch timer.phase {
        case .idle: settings.text("Ready when you are", "准备好即可开始")
        case .running: settings.text("Focus in progress", "专注进行中")
        case .finished: settings.text("Take a short break", "休息一下")
        }
    }

    private var buttonTitle: String {
        switch timer.phase {
        case .idle: settings.text("Start", "开始")
        case .running: settings.text("Stop", "停止")
        case .finished: settings.text("Show reminder", "显示提醒")
        }
    }

    private var buttonIcon: String {
        switch timer.phase {
        case .idle: "play.fill"
        case .running: "stop.fill"
        case .finished: "bell.fill"
        }
    }

    private func primaryAction() {
        switch timer.phase {
        case .idle: onStart()
        case .running: timer.stop()
        case .finished: onShowReminder()
        }
    }
}

struct ReminderView: View {
    @ObservedObject var settings: AppSettings
    let minutes: Int
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color(red: 0.87, green: 0.29, blue: 0.22))
            Text(settings.text("Time for a break", "该休息了"))
                .font(AppTypography.medium(24))
            AppTypography.text(settings.text("You completed \(minutes) minutes of focus.\nStand up, stretch, and rest your eyes.", "你已完成 \(minutes) 分钟的专注。\n起身活动一下，让眼睛休息片刻。"), size: 17)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
                .lineSpacing(5)
            Button(action: onDismiss) {
                Text(settings.text("Dismiss reminder", "关闭提醒")).font(AppTypography.medium(18))
            }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.87, green: 0.29, blue: 0.22))
                .controlSize(.large)
            Text(settings.text("This reminder stays until you dismiss it.", "此提醒会一直显示，直到你手动关闭。"))
                .font(AppTypography.regular(14))
                .foregroundStyle(.secondary)
        }
        .padding(36)
        .frame(width: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.locale, settings.language.locale)
    }
}
