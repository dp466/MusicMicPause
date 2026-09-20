#!/usr/bin/env bash
set -euo pipefail

# SwiftyDMG packages the app; signing/notarization are explicit, verified steps.
# Preview: ./script/package_for_distribution.sh --preview
# Release: DEVELOPER_ID_APPLICATION='Developer ID Application: …' \
#          NOTARY_KEYCHAIN_PROFILE='…' ./script/package_for_distribution.sh --release
MODE="${1:---release}"
case "$MODE" in
  --preview|--release) ;;
  *) echo "usage: $0 [--preview|--release]" >&2; exit 2 ;;
esac
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

for tool in xcodegen; do
  command -v "$tool" >/dev/null || { echo "$tool is required. See docs/RELEASING.md." >&2; exit 1; }
done
[[ -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]] || { echo "Set DEVELOPER_DIR to a full Xcode installation." >&2; exit 1; }
if [[ "$MODE" == --release ]]; then
  : "${DEVELOPER_ID_APPLICATION:?Set the Developer ID Application signing identity}"
  : "${NOTARY_KEYCHAIN_PROFILE:?Set a stored notarytool keychain profile name}"
  [[ "$DEVELOPER_ID_APPLICATION" == 'Developer ID Application:'* ]] || { echo "Release requires a Developer ID Application identity." >&2; exit 1; }
  SIGNING_IDENTITY="$DEVELOPER_ID_APPLICATION"
else
  SIGNING_IDENTITY="${DEVELOPMENT_IDENTITY:-Apple Development}"
fi

SWIFTY_DMG_BIN="${SWIFTY_DMG_BIN:-$("$ROOT_DIR/script/build_swifty_dmg.sh")}"
[[ -x "$SWIFTY_DMG_BIN" ]] || { echo "SwiftyDMG executable not found." >&2; exit 1; }

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/MicPauseDistribution.XXXXXX")"
STAGE_DIR="$WORK_DIR/Source"
DERIVED_DATA="$WORK_DIR/DerivedData"
CLEAN_APP="$WORK_DIR/Mic Pause.app"
MOUNT_POINT="$WORK_DIR/VerifyMount"
MOUNTED=0
cleanup() {
  if [[ "$MOUNTED" == 1 ]]; then
    /usr/bin/hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || return
  fi
  /bin/rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT
mkdir -p "$STAGE_DIR/script" "$OUTPUT_DIR"
/usr/bin/rsync -a "$ROOT_DIR/MicPause" "$ROOT_DIR/MicPauseTests" "$ROOT_DIR/project.yml" "$STAGE_DIR/"
/usr/bin/rsync -a "$ROOT_DIR/script/install_to_applications.sh" "$STAGE_DIR/script/"
(
  cd "$STAGE_DIR"
  xcodegen generate >/dev/null
  xcodebuild -quiet -project MicPause.xcodeproj -scheme MicPause \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" CODE_SIGNING_ALLOWED=NO \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
)
/usr/bin/ditto "$DERIVED_DATA/Build/Products/Release/MicPause.app" "$CLEAN_APP"
/usr/bin/xattr -cr "$CLEAN_APP"
/usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp \
  --entitlements "$ROOT_DIR/MicPause/MicPause.entitlements" "$CLEAN_APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$CLEAN_APP"

VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$CLEAN_APP/Contents/Info.plist")"
BUILD="$(/usr/bin/plutil -extract CFBundleVersion raw "$CLEAN_APP/Contents/Info.plist")"
ARCHITECTURES="$(/usr/bin/lipo -archs "$CLEAN_APP/Contents/MacOS/MicPause")"
[[ "$ARCHITECTURES" == *arm64* && "$ARCHITECTURES" == *x86_64* ]] || { echo "Expected universal binary; got $ARCHITECTURES" >&2; exit 1; }
SUFFIX=""
TRUST_NOTE="Developer ID signed and notarized by Apple."
if [[ "$MODE" == --preview ]]; then
  SUFFIX="-preview.$BUILD"
  TRUST_NOTE="Development-signed preview; not notarized by Apple. Gatekeeper may block this download."
fi
NAME="Mic-Pause-$VERSION$SUFFIX-universal"
DMG="$WORK_DIR/$NAME.dmg"
for extension in dmg sha256 INSTALL.txt; do
  [[ ! -e "$OUTPUT_DIR/$NAME.$extension" ]] || { echo "Refusing to overwrite $OUTPUT_DIR/$NAME.$extension" >&2; exit 1; }
done

# The upstream auto-signer picks an identity itself. Sign after packaging instead.
"$SWIFTY_DMG_BIN" "$CLEAN_APP" --output "$DMG" --skipcodesign --verbose
if [[ "$MODE" == --release ]]; then
  /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG"
  /usr/bin/codesign --verify --verbose=2 "$DMG"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  /usr/sbin/spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
fi
/usr/bin/hdiutil verify "$DMG"
mkdir -p "$MOUNT_POINT"
/usr/bin/hdiutil attach "$DMG" -readonly -nobrowse -mountpoint "$MOUNT_POINT" >/dev/null
MOUNTED=1
[[ -d "$MOUNT_POINT/Mic Pause.app" ]]
[[ "$(readlink "$MOUNT_POINT/Applications")" == '/Applications' ]]
/usr/bin/codesign --verify --deep --strict --verbose=2 "$MOUNT_POINT/Mic Pause.app"
/usr/bin/cmp "$CLEAN_APP/Contents/MacOS/MicPause" "$MOUNT_POINT/Mic Pause.app/Contents/MacOS/MicPause"
/usr/bin/hdiutil detach "$MOUNT_POINT" >/dev/null
MOUNTED=0
/usr/bin/ditto "$DMG" "$OUTPUT_DIR/$NAME.dmg"
(cd "$OUTPUT_DIR" && /usr/bin/shasum -a 256 "$NAME.dmg" > "$NAME.sha256")
cat > "$OUTPUT_DIR/$NAME.INSTALL.txt" <<NOTES
Mic Pause $VERSION (build $BUILD) — macOS 14 or later
Apple silicon and Intel: $ARCHITECTURES

$TRUST_NOTE

1. Open $NAME.dmg.
2. Drag Mic Pause.app into Applications, then eject the disk image.
3. Open Mic Pause from Applications. It appears in the menu bar.
4. Allow Mic Pause to control Apple Music when macOS asks.

Launch at Login is enabled on first launch. You can turn it off in Settings.
For a trusted preview that macOS blocks, review System Settings > Privacy &
Security > Open Anyway. Do not disable Gatekeeper globally.

Verify the download: shasum -a 256 -c $NAME.sha256
Support: https://github.com/dp466/MusicMicPause/issues
NOTES
printf 'Created %s\n%s\n' "$OUTPUT_DIR/$NAME.dmg" "$TRUST_NOTE"
