#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="MicPause"
PROCESS_NAME="MicPause"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/MicPause.xcodeproj"
DERIVED_DATA="${TMPDIR:-/tmp}/com.dparadis.MicPause-DerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$PROCESS_NAME"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

if pgrep -x "$PROCESS_NAME" >/dev/null 2>&1; then
  /usr/bin/osascript \
    -e 'tell application id "com.dparadis.MicPause" to quit' \
    >/dev/null 2>&1 || true

  for _ in 1 2 3 4 5; do
    pgrep -x "$PROCESS_NAME" >/dev/null 2>&1 || break
    sleep 0.2
  done

  pkill -TERM -x "$PROCESS_NAME" >/dev/null 2>&1 || true
fi

xcodebuild \
  -project "$PROJECT" \
  -scheme MicPause \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  build

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$PROCESS_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.dparadis.MicPause"'
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$PROCESS_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
