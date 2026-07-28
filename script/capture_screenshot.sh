#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS_SOURCE="$ROOT_DIR/AppStore/ScreenshotHarness"
HARNESS_BUILD="$ROOT_DIR/.build/ScreenshotHarness"
DERIVED_DATA="${TMPDIR:-/tmp}/com.dparadis.MicPause-ScreenshotHarness"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/MicPauseScreenshotHarness.app"
PROCESS_NAME="MicPauseScreenshotHarness"
EXPECTED_BUNDLE_ID="com.dparadis.MicPause.ScreenshotHarness"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required to build the screenshot harness." >&2
  exit 1
fi

pkill -TERM -x "$PROCESS_NAME" >/dev/null 2>&1 || true
mkdir -p "$HARNESS_BUILD"

xcodegen generate \
  --spec "$HARNESS_SOURCE/project.yml" \
  --project "$HARNESS_BUILD"

xcodebuild \
  -project "$HARNESS_BUILD/MicPauseScreenshotHarness.xcodeproj" \
  -scheme MicPauseScreenshotHarness \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  build

INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
ACTUAL_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
if [[ "$ACTUAL_BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]]; then
  echo "Refusing to launch screenshot harness with unsafe bundle identifier: $ACTUAL_BUNDLE_ID" >&2
  exit 1
fi

if /usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$INFO_PLIST" >/dev/null 2>&1; then
  echo "Refusing to launch screenshot harness as a menu-bar background app." >&2
  exit 1
fi

SURFACE="${1:-dashboard}"
if [[ "$SURFACE" != "dashboard" && "$SURFACE" != "settings" ]]; then
  echo "usage: $0 [dashboard|settings]" >&2
  exit 2
fi

/usr/bin/open -n "$APP_BUNDLE" --args --surface "$SURFACE"
echo "The $SURFACE screenshot window is open. Capture the window without personal information or notifications."
