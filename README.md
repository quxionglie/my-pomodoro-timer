# 番茄钟 · macOS

本项目全部代码均由 AI 编写（AI-generated code）。

使用 SwiftUI + AppKit 实现，支持 macOS 14.0 及以上版本，无第三方依赖。

应用界面全部使用英文，文字与数字使用系统 Arial，标题和按钮使用 Arial Bold，倒计时保持等宽数字。

## 使用

1. 打开应用，从列表选择 15、30、45、60、90 分钟，默认 30 分钟。
2. 点击 **Start**。窗口自动收起，应用只留在菜单栏；计时期间显示浅绿色进度环，从顶部顺时针填充，分成四段以区分 1/4、2/4、3/4 进度，不显示倒计时数字。停止或结束后恢复默认图标。
3. 点击菜单栏的计时图标可查看进度，并随时点击 **Stop**。停止后不弹出提醒。
4. 时间到后出现置顶提醒，并发出一声提示音。提醒不自动消失；切换应用、按 Esc 或 Cmd-W 均不会关闭，需点击 **Dismiss reminder**。提醒期间普通退出也需先关闭提醒。
5. 关闭提醒后可从菜单栏开始下一轮；菜单栏面板底部可退出应用。

计时期间锁定时长。关闭主窗口不退出应用。电脑休眠时无法显示提醒；唤醒后按结束时间立即校正，若已到时便显示提醒。退出应用会结束本次计时，不恢复上次倒计时。

## 统计与导出

主窗口或菜单栏面板底部的 **Statistics** 打开统计窗口，按天显示 Start、手动 Stop、自动结束次数（包括当天），日期倒序；没有 Start 记录的日期不显示。每轮按 Start 时的本地日期归属，跨午夜也不拆分。统计自动保存，重启后保留；升级前的历史无法补录。

点击 **Export Markdown…** 选择位置保存 `.md` 文件，导出全部历史，以日期为标题，包含每日次数和每轮列表。统计输出全部使用英文：`Starts`、`Manual stops`、`Automatic completions`、`Start time`、`Status`、`Manual stop time`。时间使用导出时电脑的当前时区，包含时区偏移，例如 `2026-10-20T15:10:00+08:00`；自动结束的状态为 `Completed`，手动停止为 `Terminated`，没有手动 stop 时间时显示 `—`。计时尚未结束时导出显示 `In progress`。退出或异常关闭造成的中断显示 `Terminated`，没有手动 stop 时间，也不增加手动 Stop 次数。到期后才点击 Stop 仍算自动结束，关闭提醒不重复计数。

统计窗口底部的 **Clear All…** 可在确认后清除全部统计数据，重启后也不会恢复。清除包含正在计时的记录，但不会停止倒计时；被清除的这一轮结束后不再计入统计，下一次 Start 起重新记录。

## 构建

在 Xcode 打开 `my-pomodoro-timer.xcodeproj`，选择 `my-pomodoro-timer` Scheme 和 My Mac，运行即可。

```sh
xcodebuild -project my-pomodoro-timer.xcodeproj \
  -scheme my-pomodoro-timer -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

应用输出：`build/DerivedData/Build/Products/Debug/PomodoroTimer.app`。

本地 Release 版交付为 `build/PomodoroTimer.app`，应用显示名称为 `PomodoroTimer`。

## 验证

```sh
bash scripts/test.sh       # 使用模拟时钟验证计时逻辑，无需等待真实分钟
bash scripts/test.sh --ui  # 额外运行窗口生命周期检查，需要 macOS 图形会话
```

界面检查会短暂显示测试窗口和到时提醒，完成后自动退出，并在 `build/controls.png` 和 `build/reminder.png` 保存界面预览。
