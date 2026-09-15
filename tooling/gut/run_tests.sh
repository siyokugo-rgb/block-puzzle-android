#!/usr/bin/env bash
# Phase 0-B: reproducible headless GUT runner (Godot 4.7.2 + GUT 9.7.1)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "error: godot not found in PATH (set GODOT_BIN)" >&2
  exit 127
fi

exec "$GODOT_BIN" --headless --path "$ROOT" -s addons/gut/gut_cmdln.gd \
  -gconfig=res://.gutconfig.json \
  -gexit \
  -glog=1
