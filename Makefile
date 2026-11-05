# 使用 Bash 执行命令；不指定目标时，默认显示帮助。
SHELL := /bin/bash
.DEFAULT_GOAL := help

# 本地构建目录，可通过命令行覆盖，例如 make build BUILD_DIR=build-local。
BUILD_DIR ?= build
DERIVED_DATA ?= $(BUILD_DIR)/Release
DEBUG_DERIVED_DATA ?= $(BUILD_DIR)/DerivedData

.PHONY: help debug build test test-ui

help:
	@printf '%s\n' \
	  'make debug      Build Debug locally without signing' \
	  'make build      Build Release locally without signing' \
	  'make test       Run timer and statistics checks' \
	  'make test-ui    Also run window lifecycle checks (requires a GUI session)' \
	  'Options: BUILD_DIR=build DERIVED_DATA=build/Release DEBUG_DERIVED_DATA=build/DerivedData'

# 本地 Apple Silicon 构建，无需分发证书。
# pipefail 保证构建失败时不会因 tee 成功保存日志而误报成功。
debug:
	@mkdir -p "$(BUILD_DIR)"
	@set -o pipefail; xcodebuild -project my-pomodoro-timer.xcodeproj \
	  -scheme my-pomodoro-timer -configuration Debug \
	  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$(DEBUG_DERIVED_DATA)" \
	  CODE_SIGNING_ALLOWED=NO build 2>&1 | tee "$(BUILD_DIR)/debug-build.log"

build:
	@mkdir -p "$(BUILD_DIR)"
	@set -o pipefail; xcodebuild -project my-pomodoro-timer.xcodeproj \
	  -scheme my-pomodoro-timer -configuration Release \
	  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$(DERIVED_DATA)" \
	  CODE_SIGNING_ALLOWED=NO build 2>&1 | tee "$(BUILD_DIR)/release-build.log"

# 使用模拟时钟验证计时与统计逻辑，无需等待真实计时结束。
test:
	bash scripts/test.sh

# 额外运行窗口生命周期检查，需要 macOS 图形会话。
test-ui:
	bash scripts/test.sh --ui
