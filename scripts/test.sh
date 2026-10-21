#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/test-module-cache
cp -R my-pomodoro-timer/*.lproj build/
xcrun swiftc -parse-as-library -swift-version 5 \
    -module-cache-path build/test-module-cache \
    my-pomodoro-timer/AppLocalization.swift my-pomodoro-timer/AppSettings.swift my-pomodoro-timer/SessionStatistics.swift \
    my-pomodoro-timer/PomodoroTimer.swift Tests/PomodoroTimerChecks.swift \
    -o build/PomodoroTimerChecks
build/PomodoroTimerChecks

if [[ "${1:-}" == "--ui" ]]; then
    mkdir -p build/AppLifecycleChecks.app/Contents/MacOS build/AppLifecycleChecks.app/Contents/Resources
    # Give UI previews the same version metadata as the application.
    python3 - <<'PY'
import pathlib, plistlib, re
project = pathlib.Path("my-pomodoro-timer.xcodeproj/project.pbxproj").read_text()
info = {"CFBundleExecutable": "AppLifecycleChecks", "CFBundlePackageType": "APPL"}
for setting, key in [("MARKETING_VERSION", "CFBundleShortVersionString"),
                     ("CURRENT_PROJECT_VERSION", "CFBundleVersion")]:
    info[key] = re.search(r"\b" + setting + r"\s*=\s*([^;]+);", project).group(1).strip().strip('"')
with open("build/AppLifecycleChecks.app/Contents/Info.plist", "wb") as output:
    plistlib.dump(info, output)
PY
    cp -R my-pomodoro-timer/*.lproj build/AppLifecycleChecks.app/Contents/Resources/
    cp my-pomodoro-timer/Fonts/*.otf build/AppLifecycleChecks.app/Contents/Resources/
    xcrun swiftc -parse-as-library -swift-version 5 \
        -module-cache-path build/test-module-cache \
        my-pomodoro-timer/AppLocalization.swift my-pomodoro-timer/AppSettings.swift my-pomodoro-timer/SettingsView.swift \
        my-pomodoro-timer/SessionStatistics.swift my-pomodoro-timer/StatisticsView.swift \
        my-pomodoro-timer/PomodoroTimer.swift my-pomodoro-timer/ContentView.swift \
        my-pomodoro-timer/AppDelegate.swift my-pomodoro-timer/AppTypography.swift Tests/AppLifecycleChecks.swift \
        -o build/AppLifecycleChecks.app/Contents/MacOS/AppLifecycleChecks
    build/AppLifecycleChecks.app/Contents/MacOS/AppLifecycleChecks
fi
