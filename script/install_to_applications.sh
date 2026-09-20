#!/usr/bin/env bash
set -euo pipefail

# Copies the freshly built app into /Applications.
#
# Runs as a scheme post-action, not a target build phase: code signing is the
# last thing Xcode does to a target, so a build phase would copy the bundle
# before it is signed and the result would refuse to launch.
#
# Debug builds only, so archives and the Release build in validate_release.sh
# never touch /Applications.

# Test/validation builds must never replace the installed app.
if [[ "${MICPAUSE_SKIP_INSTALL:-NO}" == "YES" || "${CODE_SIGNING_ALLOWED:-YES}" == "NO" ]]; then
  exit 0
fi

APP_PROCESS="MicPause"
BUNDLE_ID="com.dparadis.MicPause"

# Archive and `xcodebuild install` runs set ACTION=install.
if [[ "${ACTION:-build}" == "install" ]]; then
  exit 0
fi

if [[ "${CONFIGURATION:-Debug}" != "Debug" ]]; then
  exit 0
fi

if [[ -z "${BUILT_PRODUCTS_DIR:-}" || -z "${FULL_PRODUCT_NAME:-}" ]]; then
  echo "warning: no build product in the environment; skipping install." >&2
  exit 0
fi

SOURCE="$BUILT_PRODUCTS_DIR/$FULL_PRODUCT_NAME"
DESTINATION="/Applications/$FULL_PRODUCT_NAME"
STAGING="/Applications/.$FULL_PRODUCT_NAME.installing"

if [[ ! -d "$SOURCE" ]]; then
  echo "warning: $SOURCE does not exist; skipping install." >&2
  exit 0
fi

# Guard the destructive paths below against an unexpected product name.
case "$DESTINATION" in
  /Applications/*.app) ;;
  *)
    echo "error: refusing to install to $DESTINATION" >&2
    exit 1
    ;;
esac

if [[ ! -w /Applications ]]; then
  echo "warning: /Applications is not writable; skipping install." >&2
  exit 0
fi

# An unsigned or partially signed bundle will not launch; catch it here rather
# than leaving a broken app in /Applications.
if ! /usr/bin/codesign --verify "$SOURCE" 2>/dev/null; then
  echo "error: $SOURCE is not validly signed; refusing to install." >&2
  exit 1
fi

# Replacing a running bundle underneath itself corrupts the running process.
if pgrep -x "$APP_PROCESS" >/dev/null 2>&1; then
  /usr/bin/osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true

  for _ in 1 2 3 4 5; do
    pgrep -x "$APP_PROCESS" >/dev/null 2>&1 || break
    sleep 0.2
  done

  pkill -TERM -x "$APP_PROCESS" >/dev/null 2>&1 || true
fi

# Stage beside the destination, then swap, so an interrupted copy can never
# leave a half-written bundle behind.
/bin/rm -rf -- "$STAGING"
/usr/bin/rsync --archive "$SOURCE/" "$STAGING/"
/bin/rm -rf -- "$DESTINATION"
/bin/mv -f -- "$STAGING" "$DESTINATION"

if ! /usr/bin/codesign --verify "$DESTINATION" 2>/dev/null; then
  echo "error: installed bundle failed signature verification; removing it." >&2
  /bin/rm -rf -- "$DESTINATION"
  exit 1
fi

echo "Installed $DESTINATION"
