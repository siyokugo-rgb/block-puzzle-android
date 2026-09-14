#!/usr/bin/env bash
# Apply Phase 0-A.1 AGP overlay onto the Godot-generated android/build template.
# Does not vendor the full android_source.zip (~205MB).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$(cd "$(dirname "$0")" && pwd)/config.gradle"
DST="$ROOT/android/build/config.gradle"

if [[ ! -f "$DST" ]]; then
  echo "error: $DST not found. Install Godot Android Build Template first." >&2
  exit 1
fi

if [[ ! -f "$SRC" ]]; then
  echo "error: overlay source missing: $SRC" >&2
  exit 1
fi

cp "$SRC" "$DST"
echo "applied AGP overlay -> $DST"
grep -n "androidGradlePlugin\|compileSdk\|minSdk\|targetSdk" "$DST" | head -8
