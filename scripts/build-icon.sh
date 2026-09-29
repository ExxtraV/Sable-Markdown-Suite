#!/bin/sh
# Rebuilds Assets/Sable.icns from an icon master: a 1024-pixel app tile.
# Usage: build-icon.sh [master.png]   (default: Assets/sable-icon-light-1024.png)
# scripts/render-icon.swift fits the tile to the macOS icon grid and swaps in the simplified mark at small sizes.
set -eu
cd "$(dirname "$0")/.."
MASTER="${1:-Assets/sable-icon-light-1024.png}"
[ -f "$MASTER" ] || { echo "No icon master at $MASTER" >&2; exit 1; }
rm -rf build/Sable.iconset
swift scripts/render-icon.swift "$MASTER" Assets/sable-icon-small-mark.png build/Sable.iconset
python3 scripts/pack-icon.py
