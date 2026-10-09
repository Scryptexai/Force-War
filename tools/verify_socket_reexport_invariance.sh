#!/usr/bin/env bash
# Acceptance test for the weapon socket contract:
#
#   "move an Empty in Blender, re-export, and the fire point follows with no
#    code change"
#
# The test re-authors the aircraft GLB with one socket deliberately nudged in
# Blender, then asks Godot - using the same by-name lookup the game uses - where
# that socket now is. No engine source file is touched between the two reads.
#
# Usage:
#   BPY_PYTHON=/tmp/forcewar-bpy-venv/bin/python \
#   BPY_LIBS=/tmp/forcewar-bpy-libs \
#   GODOT_BIN=/tmp/force-war-godot-4.6.2/Godot_v4.6.2-stable_linux.x86_64 \
#     tools/verify_socket_reexport_invariance.sh
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
SOCKET="${SOCKET:-MZ_Gun_L}"
NUDGE="${NUDGE:-0.0,-0.37,0.0}"           # Blender space: 0.37 m further forward
SOURCE="${SOURCE:-assets/models/enemy_hero_jet_blender_ready.glb}"
BPY_PYTHON="${BPY_PYTHON:-/tmp/forcewar-bpy-venv/bin/python}"
BPY_LIBS="${BPY_LIBS:-/tmp/forcewar-bpy-libs}"
GODOT_BIN="${GODOT_BIN:-/tmp/force-war-godot-4.6.2/Godot_v4.6.2-stable_linux.x86_64}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "== 1. Blender: author the GLB unchanged, read the socket as the engine does"
LD_LIBRARY_PATH="$BPY_LIBS" "$BPY_PYTHON" tools/blender_author_weapon_sockets.py -- \
  --source "$ROOT/$SOURCE" \
  --out "$WORK/base.glb" \
  --report "$WORK/base_report.json" | grep -E "^Exported"
BASE_JSON="$("$GODOT_BIN" --headless --script tools/socket_probe.gd -- "$WORK/base.glb" "$SOCKET" | tail -1)"
echo "   $BASE_JSON"

echo "== 2. Blender: same source, same pipeline, only $SOCKET moved by $NUDGE"
LD_LIBRARY_PATH="$BPY_LIBS" "$BPY_PYTHON" tools/blender_author_weapon_sockets.py -- \
  --source "$ROOT/$SOURCE" \
  --out "$WORK/nudged.glb" \
  --report "$WORK/nudged_report.json" \
  --nudge "$SOCKET=$NUDGE" | grep -E "^nudged|^Exported"

echo "== 3. re-exported GLB: same by-name lookup, no code change"
MOVED_JSON="$("$GODOT_BIN" --headless --script tools/socket_probe.gd -- "$WORK/nudged.glb" "$SOCKET" | tail -1)"
echo "   $MOVED_JSON"

python3 - "$SOCKET" "$NUDGE" "$BASE_JSON" "$MOVED_JSON" <<'PY'
import json, sys
socket, nudge, base_raw, moved_raw = sys.argv[1:5]
base = json.loads(base_raw)[socket]
moved = json.loads(moved_raw)[socket]
if base is None or moved is None:
    raise SystemExit(f"socket {socket} missing: before={base} after={moved}")
bx, by, bz = base
mx, my, mz = moved
delta = (round(mx - bx, 4), round(my - by, 4), round(mz - bz, 4))
# Blender (x, y, z) exports to glTF/Godot as (x, z, -y).
nx, ny, nz = [float(v) for v in nudge.split(",")]
expected = (round(nx, 4), round(nz, 4), round(-ny, 4))
error = max(abs(delta[i] - expected[i]) for i in range(3))
print(f"   socket {socket}: {base} -> {moved}")
print(f"   delta {delta} expected {expected} error {error:.5f}")
if error > 0.002:
    raise SystemExit("FAIL: the engine-side socket position did not follow the Blender Empty")
print("   OK: fire point follows the Blender Empty, no code change")
PY

echo "== socket re-export invariance: PASS"
