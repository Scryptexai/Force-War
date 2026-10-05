#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLENDER_BIN="${BLENDER_BIN:-blender}"
BPy_PYTHON="${FORCE_WAR_BPY_PYTHON:-/tmp/forcewar-bpy-venv/bin/python}"
BPy_LIB_PATH="${FORCE_WAR_BPY_LD_LIBRARY_PATH:-/tmp/forcewar-bpy-libs}"
ENEMY_SOURCE="${1:-$ROOT/assets/models/enemy_hero_jet.glb}"
ENEMY_OUT="${2:-$ROOT/assets/models/enemy_hero_jet_blender_ready.glb}"

if command -v "$BLENDER_BIN" >/dev/null 2>&1; then
  "$BLENDER_BIN" --background --python "$ROOT/tools/blender_prepare_air_combat_assets.py" -- \
    --enemy-source "$ENEMY_SOURCE" \
    --enemy-out "$ENEMY_OUT"
elif [[ -x "$BPy_PYTHON" ]]; then
  if [[ -d "$BPy_LIB_PATH" ]]; then
    export LD_LIBRARY_PATH="$BPy_LIB_PATH:${LD_LIBRARY_PATH:-}"
  fi
  "$BPy_PYTHON" - <<'PY'
import bpy
print(f"Using Blender bpy runtime {bpy.app.version_string}")
PY
  "$BPy_PYTHON" "$ROOT/tools/blender_prepare_air_combat_assets.py" \
    --enemy-source "$ENEMY_SOURCE" \
    --enemy-out "$ENEMY_OUT"
else
  echo "No Blender executable found and no bpy runtime found." >&2
  echo "Install Blender and set BLENDER_BIN=/path/to/blender, or provide FORCE_WAR_BPY_PYTHON=/path/to/python with bpy installed." >&2
  exit 127
fi

echo "Blender air pipeline complete: $ENEMY_OUT"
