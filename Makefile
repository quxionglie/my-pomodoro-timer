# 使用 Bash 执行命令；不指定目标时，默认显示帮助。
SHELL := /bin/bash
.DEFAULT_GOAL := help

# 构建目录与产物路径。带 ?= 的变量可通过命令行覆盖，例如 make sign BUILD_DIR=build。
BUILD_DIR ?= build
DERIVED_DATA ?= $(BUILD_DIR)/ReleaseSigned
# 本地 Debug 构建使用独立目录，无需 Developer ID 证书。
DEBUG_DERIVED_DATA ?= $(BUILD_DIR)/DerivedData
APP_NAME := PomodoroTimer
# 默认从 Xcode 项目的 MARKETING_VERSION 读取版本号，用于 ZIP 文件名。
VERSION ?= $(shell awk '/MARKETING_VERSION =/ { gsub(/;/, "", $$3); print $$3; exit }' my-pomodoro-timer.xcodeproj/project.pbxproj)
APP := $(BUILD_DIR)/$(APP_NAME).app
# 公证上传包与附加公证票据后的发布包分别保存。
UPLOAD_ZIP := $(BUILD_DIR)/$(APP_NAME)-v$(VERSION)-notarization.zip
RELEASE_ZIP := $(BUILD_DIR)/$(APP_NAME)-v$(VERSION)-macOS.zip
# Developer ID 分发证书名称；使用其他证书时通过 SIGN_IDENTITY 覆盖。
SIGN_IDENTITY ?= Developer ID Application: xionglie qu (T6ZY4Y8T9H)
# 钥匙串中已保存的公证凭据名称，密码不写入 Makefile。
NOTARY_PROFILE ?= pomodoro-notary
# 上传完成后的公证审核等待时间；此配置不能解决上传阶段的网络超时。
NOTARY_TIMEOUT ?= 30m
# S3 上传加速：0 为关闭，1 为开启；两种模式均需上传至 Apple 使用的 S3 服务。
NOTARY_ACCELERATION ?= 0
# 将公证配置传给脚本，日志与提交编号保存在构建目录中。
NOTARY_ENV = NOTARY_PROFILE="$(NOTARY_PROFILE)" NOTARY_TIMEOUT="$(NOTARY_TIMEOUT)" NOTARY_ACCELERATION="$(NOTARY_ACCELERATION)" NOTARY_DIR="$(BUILD_DIR)"

# 声明伪目标，避免同名文件使对应命令被跳过。
.PHONY: help debug build sign verify upload-zip notarize submit status wait log staple package release test test-ui

# 显示可用命令及常用配置。
help:
	@printf '%s\n' \
	  'make debug      Build Debug locally without signing or uploading' \
	  'make sign       Build Release, sign with Developer ID and verify (no upload)' \
	  'make release    Build/sign, notarize, staple and create release ZIP' \
	  'make notarize   Build/sign, create ZIP and submit (default timeout: 30m)' \
	  'make submit     Submit the existing upload ZIP without rebuilding' \
	  'make status     Query the saved submission (or ID=...)' \
	  'make wait       Wait for the saved submission (or ID=...), without uploading' \
	  'make log        Download the saved submission log (or ID=...)' \
	  'make staple     Staple and validate the existing app' \
	  'make package    Package the existing app; requires a valid ticket' \
	  'make test       Run timer and statistics checks' \
	  'make test-ui    Also run window lifecycle checks (requires a GUI session)' \
	  'Options: NOTARY_TIMEOUT=30m NOTARY_PROFILE=pomodoro-notary NOTARY_ACCELERATION=0'

# 本地开发构建：跳过签名，不上传文件，日志保存在构建目录中。
debug:
	@mkdir -p "$(BUILD_DIR)"
	@set -o pipefail; xcodebuild -project my-pomodoro-timer.xcodeproj \
	  -scheme my-pomodoro-timer -configuration Debug \
	  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$(DEBUG_DERIVED_DATA)" \
	  CODE_SIGNING_ALLOWED=NO build 2>&1 | tee "$(BUILD_DIR)/debug-build.log"

# 构建 Apple Silicon Release，并由 Xcode 使用 Developer ID 签名和安全时间戳。
# pipefail 保证构建失败时不会因 tee 成功保存日志而误报成功。
build:
	@mkdir -p "$(BUILD_DIR)"
	@set -o pipefail; xcodebuild -project my-pomodoro-timer.xcodeproj \
	  -scheme my-pomodoro-timer -configuration Release \
	  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$(DERIVED_DATA)" \
	  CODE_SIGN_STYLE=Manual 'CODE_SIGN_IDENTITY=$(SIGN_IDENTITY)' \
	  OTHER_CODE_SIGN_FLAGS=--timestamp build 2>&1 | tee "$(BUILD_DIR)/release-signing.log"

# 先构建签名，再替换交付目录中的应用并验证；本目标不上传文件。
sign: build
	@# 删除旧的交付副本，避免复制时混入旧版本遗留文件。
	@python3 -c 'import pathlib, shutil; p=pathlib.Path("$(APP)"); shutil.rmtree(p) if p.exists() else None'
	ditto "$(DERIVED_DATA)/Build/Products/Release/$(APP_NAME).app" "$(APP)"
	@$(MAKE) verify

# 验证应用签名完整性，并输出证书、团队及时间戳等签名详情。
verify:
	codesign --verify --deep --strict --verbose=2 "$(APP)"
	codesign -dvvv "$(APP)"

# 将本次签名的应用压缩为公证上传包，保留应用目录及资源信息。
upload-zip: sign
	ditto -c -k --sequesterRsrc --keepParent "$(APP)" "$(UPLOAD_ZIP)"

# 重新构建、签名并打包后提交公证；脚本遇到失败或非 Accepted 结果时停止。
notarize: upload-zip
	@$(MAKE) submit

# 直接上传已有公证 ZIP，不重新构建；网络修复后可用此目标手动重传。
submit:
	@$(NOTARY_ENV) bash scripts/notarize.sh submit "$(UPLOAD_ZIP)"

# 查询状态、继续等待或下载审核日志，不重复上传。
# 默认读取已保存的提交编号，也可指定：make status ID=YOUR_SUBMISSION_ID。
status wait log:
	@$(NOTARY_ENV) bash scripts/notarize.sh $@ "$(ID)"

# 公证通过后，对同一份应用附加票据，验证票据、签名及 Gatekeeper 检查结果。
staple:
	xcrun stapler staple "$(APP)"
	xcrun stapler validate "$(APP)"
	codesign --verify --deep --strict --verbose=2 "$(APP)"
	spctl --assess --type execute --verbose=4 "$(APP)"

# 确认票据和签名有效后生成发布 ZIP；不能用上传包代替附加票据后的发布包。
package:
	xcrun stapler validate "$(APP)"
	codesign --verify --deep --strict --verbose=2 "$(APP)"
	ditto -c -k --sequesterRsrc --keepParent "$(APP)" "$(RELEASE_ZIP)"

# 完整发布流程：公证 → 附加票据 → 打包；任一步失败便停止。
# 分别递归调用 make，确保即使使用 make -j，各阶段仍严格顺序执行。
release:
	@$(MAKE) notarize
	@$(MAKE) staple
	@$(MAKE) package

# 使用模拟时钟验证计时与统计逻辑，无需等待真实计时结束。
test:
	bash scripts/test.sh

# 在逻辑验证之外运行窗口生命周期检查；需要 macOS 图形会话，会短暂显示测试窗口。
test-ui:
	bash scripts/test.sh --ui
