import SwiftUI

struct ContentView: View {
    @ObservedObject var timer: PomodoroTimer
    var onStart: () -> Void
    var onShowReminder: () -> Void
    var onStatistics: () -> Void
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
                    Text(timer.phase == .finished ? "Time’s up" : timer.timeText)
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

            DurationPicker(selection: Binding(
                get: { timer.selectedMinutes },
                set: { timer.select(minutes: $0) }
            ))
            .fixedSize()
            .frame(maxWidth: .infinity)
            .disabled(timer.phase != .idle)

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
                 ? "Timer is running in the background.\nClick Stop to end your session."
                 : "Start to continue in the menu bar.\nDismiss the reminder when time is up.", size: 14)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
            HStack {
                Button(action: onStatistics) {
                    Label("Statistics", systemImage: "chart.bar.xaxis")
                        .labelStyle(.iconOnly)
                        .font(AppTypography.medium(14))
                }
                .buttonStyle(.plain)
                .help("Statistics")
                .foregroundStyle(.secondary)
                Spacer()
                Button(action: onQuit) {
                    Text("Quit").font(AppTypography.medium(14))
                }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(width: 390)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var statusText: String {
        switch timer.phase {
        case .idle: "Ready when you are"
        case .running: "Focus in progress"
        case .finished: "Take a short break"
        }
    }

    private var buttonTitle: String {
        switch timer.phase {
        case .idle: "Start"
        case .running: "Stop"
        case .finished: "Show reminder"
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

// Set the native control's font explicitly: the SwiftUI menu picker can ignore
// custom fonts on macOS, including the font of its selected value.
private struct DurationPicker: NSViewRepresentable {
    @Binding var selection: Int
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.controlSize = .large
        button.font = AppTypography.nativeFont(18)
        button.menu?.font = button.font
        for minutes in PomodoroTimer.durations {
            button.addItem(withTitle: "\(minutes) min")
            button.lastItem?.tag = minutes
            button.lastItem?.attributedTitle = AppTypography.nativeText("\(minutes) min", size: 18)
        }
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectDuration(_:))
        button.setAccessibilityLabel("Focus duration")
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.selection = $selection
        button.selectItem(withTag: selection)
        button.isEnabled = isEnabled
    }

    final class Coordinator: NSObject {
        var selection: Binding<Int>

        init(selection: Binding<Int>) {
            self.selection = selection
        }

        @objc func selectDuration(_ sender: NSPopUpButton) {
            guard let item = sender.selectedItem else { return }
            selection.wrappedValue = item.tag
        }
    }
}

struct ReminderView: View {
    let minutes: Int
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color(red: 0.87, green: 0.29, blue: 0.22))
            Text("Time for a break")
                .font(AppTypography.medium(24))
            AppTypography.text("You completed \(minutes) minutes of focus.\nStand up, stretch, and rest your eyes.", size: 17)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
                .lineSpacing(5)
            Button(action: onDismiss) {
                Text("Dismiss reminder").font(AppTypography.medium(18))
            }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.87, green: 0.29, blue: 0.22))
                .controlSize(.large)
            Text("This reminder stays until you dismiss it.")
                .font(AppTypography.regular(14))
                .foregroundStyle(.secondary)
        }
        .padding(36)
        .frame(width: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
