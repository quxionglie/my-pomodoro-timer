import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let timer: PomodoroTimer
    let settings: AppSettings
    private var statusItem: NSStatusItem!
    private var idleStatusImage: NSImage?
    private var lastProgressPercent: Int?
    private let popover = NSPopover()
    private var statisticsWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var mainWindow: NSWindow?
    private var reminderPanel: NSPanel?

    override convenience init() {
        self.init(timer: PomodoroTimer(defaults: .standard), settings: AppSettings(defaults: .standard))
    }

    init(timer: PomodoroTimer, settings: AppSettings? = nil) {
        self.timer = timer
        self.settings = settings ?? AppSettings()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        timer.onChange = { [weak self] in self?.updateStatusItem() }
        timer.onFinish = { [weak self] in self?.showReminder() }
        settings.onChange = { [weak self] in self?.updateLanguage() }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification, object: nil
        )
        showMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        timer.refresh()
        if timer.phase == .finished {
            showReminder()
            return .terminateCancel
        }
        timer.interruptForQuit()
        return .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if timer.phase == .finished {
            showReminder()
        } else {
            showMainWindow()
        }
        return false
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        idleStatusImage = NSImage(systemSymbolName: "timer", accessibilityDescription: "PomodoroTimer")
        idleStatusImage?.isTemplate = true
        if let button = statusItem.button {
            button.image = idleStatusImage
            button.imagePosition = .imageLeading
            button.font = AppTypography.nativeFont(12)
            button.target = self
            button.action = #selector(togglePopover)
        }
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: controls())
        updateStatusItem()
    }

    private func controls() -> ContentView {
        ContentView(
            timer: timer,
            settings: settings,
            onStart: { [weak self] in self?.startTimer() },
            onShowReminder: { [weak self] in self?.showReminder() },
            onSettings: { [weak self] in self?.showSettings() },
            onQuit: { NSApp.terminate(nil) }
        )
    }

    func showSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView(
                timer: timer, settings: settings,
                onStatistics: { [weak self] in self?.showStatistics() }
            ))
            let window = NSWindow(contentViewController: controller)
            window.title = settings.text(.settings)
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func updateLanguage() {
        settingsWindow?.title = settings.text(.settings)
        statisticsWindow?.title = settings.text(.statistics)
        reminderPanel?.title = settings.text(.sessionComplete)
        // The progress image includes a localized accessibility description.
        lastProgressPercent = nil
        updateStatusItem()
    }

    private func showStatistics() {
        popover.performClose(nil)
        if statisticsWindow == nil {
            let controller = NSHostingController(rootView: StatisticsView(timer: timer, settings: settings))
            let window = NSWindow(contentViewController: controller)
            window.title = settings.text(.statistics)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 600, height: 480))
            window.minSize = NSSize(width: 520, height: 320)
            window.center()
            statisticsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        statisticsWindow?.makeKeyAndOrderFront(nil)
    }

    private func showMainWindow() {
        popover.performClose(nil)
        if mainWindow == nil {
            let controller = NSHostingController(rootView: controls())
            let window = NSWindow(contentViewController: controller)
            window.title = "PomodoroTimer"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            mainWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    private func startTimer() {
        timer.start()
        popover.performClose(nil)
        mainWindow?.orderOut(nil)
        settingsWindow?.orderOut(nil)
        statisticsWindow?.orderOut(nil)
        NSApp.hide(nil)
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        if timer.phase == .running {
            let percent = Int((min(1, max(0, timer.progress)) * 100).rounded(.down))
            if percent != lastProgressPercent {
                button.image = progressStatusImage(percent: percent)
                lastProgressPercent = percent
            }
        } else {
            lastProgressPercent = nil
            if button.image !== idleStatusImage { button.image = idleStatusImage }
        }
        switch timer.phase {
        case .idle:
            button.title = ""
            button.toolTip = settings.text(.idleTooltip)
        case .running:
            button.title = ""
            button.toolTip = settings.text(.runningTooltip, timer.timeText)
        case .finished:
            button.title = settings.text(.timesUpStatus)
            button.toolTip = settings.text(.reminderTooltip)
        }
        button.attributedTitle = AppTypography.nativeText(button.title, size: 12)
    }

    private func progressStatusImage(percent: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let green = NSColor(calibratedRed: 0.56, green: 0.84, blue: 0.60, alpha: 1)
            let elapsedAngle = Double(percent) * 3.6
            // Four separated segments mark the quarter milestones, clockwise from noon.
            for quarter in 0..<4 {
                let start = Double(quarter) * 90 + 5
                let end = Double(quarter + 1) * 90 - 5
                let track = NSBezierPath()
                track.appendArc(withCenter: NSPoint(x: 9, y: 9), radius: 6.5,
                                startAngle: CGFloat(90 - start), endAngle: CGFloat(90 - end),
                                clockwise: true)
                track.lineWidth = 2.5
                track.lineCapStyle = .butt
                green.withAlphaComponent(0.3).setStroke()
                track.stroke()

                let filledEnd = min(end, elapsedAngle)
                if filledEnd > start {
                    let filled = NSBezierPath()
                    filled.appendArc(withCenter: NSPoint(x: 9, y: 9), radius: 6.5,
                                     startAngle: CGFloat(90 - start), endAngle: CGFloat(90 - filledEnd),
                                     clockwise: true)
                    filled.lineWidth = 2.5
                    filled.lineCapStyle = .butt
                    green.setStroke()
                    filled.stroke()
                }
            }
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = settings.text(.progressDescription, percent)
        return image
    }

    @objc private func togglePopover() {
        timer.refresh()
        if timer.phase == .finished {
            showReminder()
            return
        }
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func didWake() {
        timer.refresh()
        if timer.phase == .finished { showReminder() }
    }

    private func showReminder() {
        guard timer.phase == .finished else { return }
        popover.performClose(nil)
        mainWindow?.orderOut(nil)
        if reminderPanel == nil {
            let panel = ReminderPanel(
                contentRect: .zero, styleMask: [.titled],
                backing: .buffered, defer: false
            )
            panel.title = settings.text(.sessionComplete)
            let controller = NSHostingController(rootView: ReminderView(
                settings: settings,
                minutes: timer.selectedMinutes,
                onDismiss: { [weak self] in self?.dismissReminder() }
            ))
            panel.contentViewController = controller
            panel.setContentSize(controller.view.fittingSize)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hidesOnDeactivate = false
            panel.canHide = false
            panel.isFloatingPanel = true
            // isFloatingPanel changes the level; apply the reminder level afterward.
            panel.level = .modalPanel
            panel.isReleasedWhenClosed = false
            panel.delegate = self
            panel.center()
            reminderPanel = panel
            NSSound.beep()
        }
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        reminderPanel?.makeKeyAndOrderFront(nil)
        reminderPanel?.orderFrontRegardless()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // No title-bar close, Escape, or Cmd-W may dismiss the reminder.
        sender !== reminderPanel
    }

    private func dismissReminder() {
        reminderPanel?.orderOut(nil)
        reminderPanel = nil
        timer.dismissReminder()
    }
}

private final class ReminderPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) {}
    override func performClose(_ sender: Any?) {}
}
