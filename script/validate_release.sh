#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/MicPause.xcodeproj"
VALIDATION_DIR="$(mktemp -d "${TMPDIR:-/tmp}/MicPauseReleaseValidation.XXXXXX")"
DERIVED_DATA="$VALIDATION_DIR/DerivedData"

cleanup() {
  /bin/rm -rf -- "$VALIDATION_DIR"
}
trap cleanup EXIT

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ ! -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
  echo "Xcode was not found at $DEVELOPER_DIR." >&2
  exit 1
fi

xcodebuild \
  -quiet \
  -project "$PROJECT" \
  -scheme MicPause \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  MICPAUSE_SKIP_INSTALL=YES \
  test

xcodebuild \
  -quiet \
  -project "$PROJECT" \
  -scheme MicPause \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_BUNDLE="$DERIVED_DATA/Build/Products/Release/MicPause.app"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"

[[ -d "$APP_BUNDLE" ]]
[[ -f "$INFO_PLIST" ]]
[[ -f "$APP_BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy" ]]

[[ "$(plutil -extract CFBundleIdentifier raw "$INFO_PLIST")" == "com.dparadis.MicPause" ]]
[[ "$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")" == "1.0" ]]
[[ "$(plutil -extract CFBundleVersion raw "$INFO_PLIST")" == "1" ]]
[[ "$(plutil -extract ITSAppUsesNonExemptEncryption raw "$INFO_PLIST")" == "false" ]]
[[ "$(plutil -extract LSApplicationCategoryType raw "$INFO_PLIST")" == "public.app-category.utilities" ]]

if xattr -lr "$APP_BUNDLE" | grep -q "com.apple.quarantine"; then
  echo "Release build contains a com.apple.quarantine extended attribute." >&2
  exit 1
fi

for image in "$ROOT_DIR"/AppStore/Screenshots/Final/*.jpg; do
  width="$(sips -g pixelWidth "$image" | awk '/pixelWidth/ { print $2 }')"
  height="$(sips -g pixelHeight "$image" | awk '/pixelHeight/ { print $2 }')"
  alpha="$(sips -g hasAlpha "$image" | awk '/hasAlpha/ { print $2 }')"

  [[ "$width" == "2560" ]]
  [[ "$height" == "1600" ]]
  [[ "$alpha" == "no" ]]
done

(
  cd "$ROOT_DIR/website"
  npm test
  npm audit --omit=dev --audit-level=high
)

if grep -R -q "OWNER ACTION REQUIRED" "$ROOT_DIR/website/app"; then
  echo "Warning: add the public support email before publishing the website." >&2
fi

echo "Mic Pause release validation passed."
