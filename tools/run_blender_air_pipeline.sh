#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLENDER_BIN="${BLENDER_BIN:-blender}"
ENEMY_SOURCE="${1:-$ROOT/assets/models/enemy_hero_jet.glb}"
ENEMY_OUT="${2:-$ROOT/assets/models/enemy_hero_jet_blender_ready.glb}"

if ! command -v "$BLENDER_BIN" >/dev/null 2>&1; then
  echo "Blender binary not found: $BLENDER_BIN" >&2
  echo "Install Blender or set BLENDER_BIN=/path/to/blender, then rerun this script." >&2
  exit 127
fi

"$BLENDER_BIN" --background --python "$ROOT/tools/blender_prepare_air_combat_assets.py" -- \
  --enemy-source "$ENEMY_SOURCE" \
  --enemy-out "$ENEMY_OUT"

echo "Blender air pipeline complete: $ENEMY_OUT"
