# 番茄钟 · macOS

本项目全部代码均由 AI 编写（AI-generated code）。

使用 SwiftUI + AppKit 实现，支持 macOS 14.0 及以上版本，无第三方依赖。

当前版本：**1.0（构建号 2）**。更新内容见[版本发布说明](CHANGELOG.md)。

应用界面支持英文、简体中文和繁体中文，默认英文，可在设置中即时切换。文字与数字使用系统 Arial，标题和按钮使用 Arial Bold，中文使用系统字体回退，倒计时保持等宽数字。

## 使用

1. 打开应用，首页直接显示已选时长，默认 30 分钟。点击底部齿轮打开 **Settings／设置**，可从列表选择 15、30、45、60、90 分钟、进入统计、切换英文、简体中文或繁体中文。时长和语言均自动保存，重启后保留；首页和菜单栏面板不再显示时长选择或统计按钮。
2. 点击 **Start**。窗口自动收起，应用只留在菜单栏；计时期间显示浅绿色进度环，从顶部顺时针填充，分成四段以区分 1/4、2/4、3/4 进度，不显示倒计时数字。停止或结束后恢复默认图标。
3. 点击菜单栏的计时图标可查看进度，并随时点击 **Stop**。停止后不弹出提醒。
4. 时间到后出现置顶提醒，并发出一声提示音。提醒不自动消失；切换应用、按 Esc 或 Cmd-W 均不会关闭，需点击 **Dismiss reminder**。提醒期间普通退出也需先关闭提醒。
5. 关闭提醒后可从菜单栏开始下一轮；菜单栏面板底部可退出应用。

计时期间锁定时长。关闭主窗口不退出应用。电脑休眠时无法显示提醒；唤醒后按结束时间立即校正，若已到时便显示提醒。退出应用会结束本次计时，不恢复上次倒计时。

## 统计与导出

从 **Settings／设置 → Statistics／统计** 打开统计窗口，按天显示 Start、手动 Stop、自动结束次数（包括当天），日期倒序；没有 Start 记录的日期不显示。每轮按 Start 时的本地日期归属，跨午夜也不拆分。统计自动保存，重启后保留；升级前的历史无法补录。

点击 **Export Markdown…／导出 Markdown…** 选择位置保存 `.md` 文件，导出全部历史，以日期为标题，包含每日次数和每轮列表。导出的 Markdown 始终使用英文：`Starts`、`Manual stops`、`Automatic completions`、`Start time`、`Status`、`Manual stop time`。时间使用导出时电脑的当前时区，包含时区偏移，例如 `2026-10-20T15:10:00+08:00`；自动结束的状态为 `Completed`，手动停止为 `Terminated`，没有手动 stop 时间时显示 `—`。计时尚未结束时导出显示 `In progress`。退出或异常关闭造成的中断显示 `Terminated`，没有手动 stop 时间，也不增加手动 Stop 次数。到期后才点击 Stop 仍算自动结束，关闭提醒不重复计数。

统计窗口底部的 **Clear All…** 可在确认后清除全部统计数据，重启后也不会恢复。清除包含正在计时的记录，但不会停止倒计时；被清除的这一轮结束后不再计入统计，下一次 Start 起重新记录。

## 多语言文案

界面通过 `AppText` 标识引用文案，翻译集中维护在 `my-pomodoro-timer/en.lproj/Localizable.strings`、`zh-Hans.lproj/Localizable.strings` 和 `zh-Hant.lproj/Localizable.strings`。新增文案时同步更新三个语言文件和 `AppLocalization.swift` 中的标识；带参数的文案须保留 `%d`、`%@` 等格式占位符，字面百分号写成 `%%`。

## 构建

需要 macOS 和完整 Xcode。以下命令均在项目根目录执行，使用 `make help` 查看可用命令。

本地 Debug 构建（Apple Silicon，无需分发证书，不上传）：

```sh
make debug
```

应用输出：`build/DerivedData/Build/Products/Debug/PomodoroTimer.app`。

Release 签名和公证需要本机已安装 Developer ID Application 证书，并已在钥匙串保存公证凭据：

```sh
make sign       # 构建并签名，不上传
make release    # 构建、签名、公证、附加票据和打包；默认等待 30m
```

`make sign` 输出应用为 `build/PomodoroTimer.app`；`make release` 完成后，发布包为 `build/PomodoroTimer-v1.0-macOS.zip`。

分步公证及查询：

```sh
make notarize   # 重新构建、签名、打包并提交公证
make submit     # 重传已有公证 ZIP，不重新构建
make status     # 查询最后一次保存的提交编号
make wait       # 继续等待原提交，不重复上传
make log        # 下载审核日志
make staple     # 公证通过后附加票据并验证
make package    # 将附加有效票据的应用压缩为发布包
```

公证需要能够上传至 Apple 使用的 S3 端点。网络失败时流程会停止，不会自动重试。分步操作和配置见[签名与公证说明](docs/SIGNING_AND_NOTARIZATION.md)。

## 验证

```sh
make test       # 使用模拟时钟验证计时与统计逻辑
make test-ui    # 额外运行窗口生命周期检查，需要 macOS 图形会话
```

界面检查会短暂显示测试窗口和到时提醒，完成后自动退出，并在 `build/controls.png` 和 `build/reminder.png` 保存界面预览。
