#!/usr/bin/env bash
# Generate the Xcode project from project.yml and build the menu bar app (Debug).
# The .xcodeproj is generated, never committed. Requires xcodegen (brew install xcodegen).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

command -v xcodegen >/dev/null || { echo "xcodegen not found: brew install xcodegen" >&2; exit 1; }

echo "==> xcodegen generate"
xcodegen generate

echo "==> xcodebuild (Debug)"
xcodebuild -project ScreenpipeMenubar.xcodeproj \
  -scheme ScreenpipeMenubar \
  -configuration Debug \
  -derivedDataPath .build \
  CODE_SIGNING_ALLOWED=NO \
  build

APP="$(/usr/bin/find .build/Build/Products -maxdepth 2 -name 'ScreenpipeMenubar.app' -print -quit 2>/dev/null || true)"
echo "==> built: ${APP:-<not found>}"
