#!/usr/bin/env bash
set -euo pipefail

# Rebuilds every icon rendition from the shared mark in
# MicPause/Views/MicPauseMark.swift. Run it after changing the mark geometry.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${TMPDIR:-/tmp}/com.dparadis.MicPause-IconGenerator"
BINARY="$BUILD_DIR/generate_app_icon"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

mkdir -p "$BUILD_DIR"

xcrun swiftc \
  -O \
  -swift-version 6 \
  -o "$BINARY" \
  "$ROOT_DIR/script/generate_app_icon.swift" \
  "$ROOT_DIR/MicPause/Views/MicPauseMark.swift"

cd "$ROOT_DIR"
"$BINARY"
