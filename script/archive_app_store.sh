#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/MicPause.xcodeproj"
ARCHIVE_DIR="$ROOT_DIR/dist"
ARCHIVE_PATH="$ARCHIVE_DIR/MicPause.xcarchive"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-QU4R4G95KN}"

if [[ ! -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
  echo "Install a supported release version of Xcode or set DEVELOPER_DIR." >&2
  exit 1
fi

if [[ "$DEVELOPER_DIR" == *"beta"* && "${ALLOW_BETA_ARCHIVE:-0}" != "1" ]]; then
  echo "Refusing to create the App Store archive with a beta Xcode." >&2
  echo "Use a currently supported release Xcode, or explicitly set ALLOW_BETA_ARCHIVE=1 after confirming App Store Connect support." >&2
  exit 1
fi

if [[ -e "$ARCHIVE_PATH" ]]; then
  echo "$ARCHIVE_PATH already exists. Move it aside before creating another archive." >&2
  exit 1
fi

mkdir -p "$ARCHIVE_DIR"

xcodebuild \
  -project "$PROJECT" \
  -scheme MicPause \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates \
  archive

APP_BUNDLE="$ARCHIVE_PATH/Products/Applications/MicPause.app"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
codesign -d --entitlements :- "$APP_BUNDLE"

if xattr -lr "$APP_BUNDLE" | grep -q "com.apple.quarantine"; then
  echo "Archive contains a com.apple.quarantine extended attribute." >&2
  exit 1
fi

echo "Archive created at $ARCHIVE_PATH"
echo "Open it in Xcode Organizer, run Validate App, then upload it to App Store Connect."
