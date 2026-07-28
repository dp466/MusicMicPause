#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${TMPDIR:-/tmp}/com.dparadis.MicPause-DerivedData"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

xcodebuild \
  -project "$ROOT_DIR/MicPause.xcodeproj" \
  -scheme MicPause \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  test
