# macOS 本地签名与公证

用于将 PomodoroTimer 发布到 GitHub Release。以下命令在项目根目录的 macOS 终端执行，需要安装完整 Xcode。

流程：Release 构建并签名 → 压缩上传 → 公证通过 → 附加公证票据 → 重新压缩发布。

## 使用 Makefile 自动执行

本文中的 `YOUR_NAME`、`YOUR_TEAM_ID` 和 `YOUR_SUBMISSION_ID` 均为占位符，请替换为你自己的证书姓名、开发者团队 ID 和公证提交编号。`pomodoro-notary` 是示例钥匙串配置名称，可以自行修改。

```bash
export SIGN_IDENTITY='Developer ID Application: YOUR_NAME (YOUR_TEAM_ID)'
make sign          # 仅重新构建、签名和验证，不上传
make release       # 完整流程：构建、签名、公证、附加票据、生成发布 ZIP
```

通过 `SIGN_IDENTITY` 指定本机的 Developer ID 证书；默认使用钥匙串配置 `pomodoro-notary`、Apple Silicon 构建，公证等待超时为 **30m**，关闭 S3 上传加速。可覆盖配置：

```bash
make release NOTARY_TIMEOUT=30m NOTARY_PROFILE=pomodoro-notary
make release NOTARY_ACCELERATION=1  # 使用 S3 加速端点
```

分步执行及恢复：

```bash
make notarize      # 重新构建、签名、压缩并提交公证
make submit        # 重传已有公证 ZIP，不重新构建和签名
make status        # 查询最后保存的提交 ID
make wait          # 继续等待原提交，不重复上传
make log           # 下载原提交的审核日志
make status ID=YOUR_SUBMISSION_ID
make wait ID=YOUR_SUBMISSION_ID NOTARY_TIMEOUT=30m
make staple        # 公证 Accepted 后，对同一份应用附加票据并验证
make package       # 生成发布 ZIP；必须已存在有效公证票据
```

构建日志保存在 `build/release-signing.log`，每次公证操作的日志保存在 `build/notarization-日期-时间-进程号.log`，提交编号保存在 `build/notarization-submission-id.txt`。上传失败或未返回 `Accepted` 时，完整流程会停止，不会继续附加票据和生成发布 ZIP，也不会自动重试。

如果上传已完成、只是等待审核超时，使用 `make wait`；通过后执行 `make staple` 和 `make package`。如果上传因 S3 网络错误失败，应先修复网络，再执行 `make submit`。两种 S3 端点均无法上传时，Makefile 无法绕过 S3；延长 `NOTARY_TIMEOUT` 也不会修复上传超时。

构建版本号取自 Xcode 项目；ZIP 文件名中的版本默认取自 `MARKETING_VERSION`。不要同时运行多个发布或公证命令。新的构建会替换本地应用，等待审核期间请保留原应用。

## 1. 准备证书

需要 Apple Developer Program 会员，以及带有私钥的 **Developer ID Application** 证书。

在 **Xcode → Settings → Apple Accounts → 选择团队 → Manage Certificates → ＋ → Developer ID Application** 中创建，或导入已有证书及私钥。

检查本机可用证书：

```bash
security find-identity -v -p codesigning
```

证书名称格式（示例占位符）：

```text
Developer ID Application: YOUR_NAME (YOUR_TEAM_ID)
```

`Apple Development` 用于开发调试，不能替代上述分发证书。如果在受限沙盒里执行命令，可能无法正确读取钥匙串，应在本机终端检查。

## 2. 保存公证凭据（只需设置一次）

打开 [Apple 账号网站](https://account.apple.com/)，进入 **登录和安全 → App 专用密码 → 生成 App 专用密码**，名称可填 `Pomodoro Notary`。账号需要开启双重认证。

在终端执行：

```bash
xcrun notarytool store-credentials "pomodoro-notary" \
  --team-id YOUR_TEAM_ID
```

按提示输入开发者 Apple ID 和生成的 App 专用密码。密码输入时不显示字符属于正常情况。验证成功后凭据保存在钥匙串中，后续使用 `pomodoro-notary` 调用，无需再次填写密码。

如果已经保存成功，可以跳过此步。不要将密码写入项目文件或提交到 Git。

## 3. 构建并签名 Release

```bash
xcodebuild -project my-pomodoro-timer.xcodeproj \
  -scheme my-pomodoro-timer \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/ReleaseSigned \
  CODE_SIGN_STYLE=Manual \
  'CODE_SIGN_IDENTITY=Developer ID Application: YOUR_NAME (YOUR_TEAM_ID)' \
  OTHER_CODE_SIGN_FLAGS=--timestamp \
  build
```

出现 `BUILD SUCCEEDED` 后再继续。如弹出钥匙串授权窗口，允许 `codesign` 使用证书。

项目已启用 Hardened Runtime，Xcode 会生成并保留应用需要的授权。不要添加 `CODE_SIGNING_ALLOWED=NO`，那会跳过签名。上述命令生成 Apple Silicon（arm64）版本。

将已签名应用复制到交付目录：

```bash
ditto build/ReleaseSigned/Build/Products/Release/PomodoroTimer.app \
  build/PomodoroTimer.app
```

## 4. 验证签名并打包上传文件

```bash
codesign --verify --deep --strict --verbose=2 build/PomodoroTimer.app
codesign -dv --verbose=4 build/PomodoroTimer.app
```

应看到签名验证通过，签名详情包含：

```text
Authority=Developer ID Application: YOUR_NAME (YOUR_TEAM_ID)
TeamIdentifier=YOUR_TEAM_ID
```

同时检查存在 `Timestamp` 和 `runtime` 标记；`Signature=adhoc` 不属于正式分发签名。

创建专门用于公证上传的 ZIP：

```bash
ditto -c -k --sequesterRsrc --keepParent \
  build/PomodoroTimer.app build/PomodoroTimer-v1.0-notarization.zip
```

## 5. 提交公证

```bash
xcrun notarytool submit build/PomodoroTimer-v1.0-notarization.zip \
  --keychain-profile "pomodoro-notary" \
  --wait --timeout 30m
```

保存输出中的提交编号（Submission ID）。只有最终状态为 **Accepted** 才表示公证通过。

- `In Progress`：尚未完成。仅拿到提交编号不能证明文件已上传完整，还需确认命令报告上传成功。
- `Invalid`：公证未通过，查看日志后修复并重新签名、打包、提交。
- 等待超时但上传已成功：Apple 仍可能继续处理，使用原提交编号查询，无需立即重复上传。`--timeout` 限制等待结果的时间，不解决文件上传阶段的网络超时。

查询历史及指定提交（把 `YOUR_SUBMISSION_ID` 替换为实际编号）：

```bash
xcrun notarytool history --keychain-profile "pomodoro-notary"

xcrun notarytool info YOUR_SUBMISSION_ID \
  --keychain-profile "pomodoro-notary"

xcrun notarytool wait YOUR_SUBMISSION_ID \
  --keychain-profile "pomodoro-notary" --timeout 30m
```

若状态为 `Invalid`，下载审核日志：

```bash
xcrun notarytool log YOUR_SUBMISSION_ID \
  --keychain-profile "pomodoro-notary" build/notarization-log.json
```

## 6. 附加公证票据并验证

确认状态为 **Accepted** 后，对本次上传对应的同一份应用执行：

```bash
xcrun stapler staple build/PomodoroTimer.app
xcrun stapler validate build/PomodoroTimer.app
codesign --verify --deep --strict --verbose=2 build/PomodoroTimer.app
spctl --assess --type execute --verbose=4 build/PomodoroTimer.app
```

应看到票据验证成功，Gatekeeper 检查返回 `accepted`，来源为 `Notarized Developer ID`。

附加票据后，不要修改应用包内文件或重新签名。若重新构建或签名，应重新提交公证。

## 7. 生成 GitHub Release 附件

票据附加成功后，重新压缩应用：

```bash
ditto -c -k --sequesterRsrc --keepParent \
  build/PomodoroTimer.app build/PomodoroTimer-v1.0-macOS.zip
```

将 `build/PomodoroTimer-v1.0-macOS.zip` 上传到 GitHub Release。不要误用第 4 步生成的上传包，它不包含后来附加的票据。

发布说明可复制 [CHANGELOG.md](../CHANGELOG.md) 中的内容。后续版本需要同步调整构建版本号及文件名。

## 上传超时如何处理

本项目此前出现过以下错误，文件未完整上传，公证也未完成：

```text
SotoS3.S3ErrorType.multipart error 1
HTTPClientError.deadlineExceeded
abortedUpload(... completedParts: [])
```

这些信息指向文件上传阶段；不能据此判断证书或代码被 Apple 拒绝。Xcode 和命令行都使用 S3 上传，换工具不一定能解决。

建议按顺序尝试：

1. 换手机热点，排查当前网络、路由器或防火墙限制。
2. 如果使用代理或 VPN，检查 S3 上传是否被正确转发，尝试更换节点或切换全局模式。
3. 关闭 S3 上传加速后重试：

```bash
xcrun notarytool submit build/PomodoroTimer-v1.0-notarization.zip \
  --keychain-profile "pomodoro-notary" \
  --no-s3-acceleration \
  --wait --timeout 30m
```

4. 查看 [Apple 开发者服务状态](https://developer.apple.com/system-status/)，排查服务故障。

此前关闭加速的尝试也曾超时，因此优先更换网络。签名已经有效时，无需因上传超时重建证书；应用未改变时可以直接重传同一份 ZIP。

## Xcode 图形界面替代流程

在 Xcode 中选择 **Product → Archive**，在 Organizer 选择归档并点击 **Distribute App → Direct Distribution → Distribute**。

该方式通过已登录账号处理签名和公证，不必手动配置 `notarytool` 密码。等待状态变为可分发后，使用 **Export App** 导出应用，并验证票据后压缩上传 GitHub。应使用导出的应用，不要误用 `build/` 中另一份旧应用。

## 官方参考

- [Developer ID 签名](https://developer.apple.com/developer-id/)
- [自定义公证流程、上传网络要求和票据附加](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [生成 App 专用密码](https://support.apple.com/zh-cn/102654)
