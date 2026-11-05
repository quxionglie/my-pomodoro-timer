# 使用 Xcode 签名、公证与发布

本项目的 Makefile 仅提供本地构建和应用测试。目前正式版本的构建、归档、签名、上传公证与导出均由开发者在 Xcode IDE 中人工操作；发布包由 Finder 压缩后，手动上传到 GitHub Release。

## 本地构建

需要 macOS 和完整 Xcode。在项目根目录执行：

```sh
make debug  # Debug 构建
make build  # Release 构建
```

两种构建均面向 Apple Silicon（arm64），跳过签名，无需分发证书或公证凭据，适合本地开发验证。

| 命令 | 应用输出 | 构建日志 |
| --- | --- | --- |
| `make debug` | `build/DerivedData/Build/Products/Debug/PomodoroTimer.app` | `build/debug-build.log` |
| `make build` | `build/Release/Build/Products/Release/PomodoroTimer.app` | `build/release-build.log` |

可用 `BUILD_DIR` 覆盖构建根目录，或用 `DERIVED_DATA`、`DEBUG_DERIVED_DATA` 分别指定 Release、Debug 的 Derived Data 目录。例如：

```sh
make build BUILD_DIR=build-local
```

本地构建产物未完成分发签名和公证；正式发布请按下面的 Xcode 流程操作。

## 在 Xcode IDE 中人工构建、签名与上传公证

1. 打开 `my-pomodoro-timer.xcodeproj`，在 **Xcode → Settings → Apple Accounts** 登录已加入 Apple Developer Program 的账号。
2. 在应用 Target 的 **Signing & Capabilities** 中确认开发团队及签名设置。分发需要可用的 **Developer ID Application** 证书和对应私钥；本项目已启用 Hardened Runtime。
3. 确认版本号和构建号，选择 macOS 运行目标，然后执行 **Product → Archive**。
4. 在 **Window → Organizer → Archives** 中选中本次归档，点击 **Distribute App**，选择 **Direct Distribution**，按向导完成签名、上传和公证。不同 Xcode 版本也可能在 **Custom → Developer ID** 下提供相应入口。
5. 等待公证成功，再使用 **Export App / Export Notarized App** 导出 `PomodoroTimer.app`（按钮名称随 Xcode 版本而异）。

如果已有公证成功的归档，直接从 Organizer 导出即可。后续打包应使用该次导出的应用，不要混用 `build/` 中的本地构建产物。导出后不要修改应用包内文件。

如公证失败，在 Organizer 查看该次分发的错误或日志；修复后通过 Xcode 重新分发。

## 生成并上传 GitHub Release 附件

1. 在 Finder 中右键导出的 `PomodoroTimer.app`，选择 **压缩“PomodoroTimer”**。
2. 将生成的 ZIP 重命名为 `PomodoroTimer-v1.0-macOS.zip`，后续版本相应调整文件名。
3. 在 GitHub 仓库打开 **Releases → Draft a new release**，选择或创建 `v1.0` 标签，填写标题和发布说明。发布说明可参考 [CHANGELOG.md](../CHANGELOG.md)。
4. 将 ZIP 上传到正文编辑框下方独立的附件区域（Attach binaries），等待上传完成后点击 **Publish release**。

Release 单个附件须小于 2 GiB，27 MB 的 ZIP 可以上传。若提示 25 MB 限制，请确认使用的是 Release 附件区域，而不是正文附件或仓库文件上传入口。

## 官方参考

- [Apple：分发应用](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [Apple：Developer ID](https://developer.apple.com/developer-id/)
- [GitHub：管理 Release](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)
- [GitHub：Release 附件大小限制](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases#storage-and-bandwidth-quotas)
