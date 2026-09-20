#!/usr/bin/env bash
set -euo pipefail

# Keep a pinned, patched tool in a local cache; never modify Homebrew's copy.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
REVISION=844cf6291cb1102b08df5992fa0e4355b62eb964
PATCH="$ROOT_DIR/script/patches/swifty-dmg-hdiutil-exit-status.patch"
PATCH_HASH="$(shasum -a 256 "$PATCH" | awk '{print $1}')"
TOOL_DIR="${SWIFTY_DMG_CACHE:-${TMPDIR:-/tmp}/com.dparadis.MicPause-SwiftyDMG}/$REVISION-$PATCH_HASH"
BINARY="$TOOL_DIR/.build/release/swifty-dmg"
if [[ -x "$BINARY" && -f "$TOOL_DIR/.micpause-build-complete" ]]; then
  printf '%s\n' "$BINARY"
  exit 0
fi
if [[ ! -d "$TOOL_DIR/.git" ]]; then
  mkdir -p "$(dirname "$TOOL_DIR")"
  git clone --depth 1 --branch v1.0.4 https://github.com/chocoford/SwiftyDMG.git "$TOOL_DIR" >&2
fi
[[ "$(git -C "$TOOL_DIR" rev-parse HEAD)" == "$REVISION" ]]
(
  cd "$TOOL_DIR"
  swift package resolve >&2
  git diff --exit-code -- Package.resolved >&2
  while read -r dependency revision; do
    [[ "$(git -C ".build/checkouts/$dependency" rev-parse HEAD)" == "$revision" ]] || {
      echo "Unexpected revision for $dependency; refusing an unpinned build." >&2
      exit 1
    }
  done <<'PINS'
AppDMG a62220e6ed548eb9e85f6daa776040db425307f5
hdiutil 19c6039fec0ba17c0a1e67daac9a8ff330420bc0
DSStoreKit a04cbdaf9c7294e045dc437e92d03bb709a5c335
swift-argument-parser c8ed701b513cf5177118a175d85fbbbcd707ab41
PINS
  if ! git -C .build/checkouts/hdiutil apply --reverse --check "$PATCH" 2>/dev/null; then
    chmod u+w .build/checkouts/hdiutil/Sources/hdiutil/hdiutil.swift
    git -C .build/checkouts/hdiutil apply "$PATCH"
  fi
  swift build -c release --disable-sandbox --force-resolved-versions >&2
)
[[ -x "$BINARY" ]]
touch "$TOOL_DIR/.micpause-build-complete"
printf '%s\n' "$BINARY"
