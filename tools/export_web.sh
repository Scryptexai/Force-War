#!/usr/bin/env bash
set -euo pipefail

# Export Force War: Storm Convoy to Godot 4.6.2 Web.
# Output in repository root: index.html, index.js, index.wasm, index.pck

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_VERSION="4.6.2.stable"
GODOT_RELEASE_TAG="4.6.2-stable"
GODOT_ZIP="$ROOT_DIR/Godot_v4.6.2-stable_linux.x86_64.zip"
GODOT_REPO_BIN="$ROOT_DIR/godot_v4.6.2-stable-linux_release.x86_64"
GODOT_BIN="${GODOT_BIN:-/tmp/force-war-godot-4.6.2/Godot_v4.6.2-stable_linux.x86_64}"
TEMPLATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$GODOT_VERSION"
TEMPLATE_URL="https://github.com/godotengine/godot-builds/releases/download/$GODOT_RELEASE_TAG/Godot_v4.6.2-stable_export_templates.tpz"
TEMPLATE_ARCHIVE="${GODOT_TEMPLATE_ARCHIVE:-/tmp/Godot_v4.6.2-stable_export_templates.tpz}"
DOWNLOAD_ZIP_URL="https://github.com/godotengine/godot-builds/releases/download/$GODOT_RELEASE_TAG/Godot_v4.6.2-stable_linux.x86_64.zip"

is_valid_godot() {
  local bin="$1"
  [[ -x "$bin" ]] || return 1
  "$bin" --version 2>/dev/null | grep -q '^4\.6\.2\.stable'
}

prepare_godot() {
  if is_valid_godot "$GODOT_BIN"; then
    return
  fi

  if is_valid_godot "$GODOT_REPO_BIN"; then
    GODOT_BIN="$GODOT_REPO_BIN"
    return
  fi

  if [[ -x "$GODOT_REPO_BIN" ]]; then
    echo "Warning: $GODOT_REPO_BIN exists but does not run as Godot 4.6.2 stable." >&2
    echo "Replace it with the official binary or put Godot_v4.6.2-stable_linux.x86_64.zip in the repo root." >&2
  fi

  if [[ ! -f "$GODOT_ZIP" ]]; then
    echo "Godot 4.6.2 zip not found: $GODOT_ZIP" >&2
    echo "Attempting download from official release:" >&2
    echo "  $DOWNLOAD_ZIP_URL" >&2
    curl -L --fail --retry 3 --continue-at - -o "$GODOT_ZIP" "$DOWNLOAD_ZIP_URL"
  fi

  mkdir -p "$(dirname "$GODOT_BIN")"
  unzip -o "$GODOT_ZIP" -d "$(dirname "$GODOT_BIN")" >/dev/null
  chmod +x "$GODOT_BIN"

  if ! is_valid_godot "$GODOT_BIN"; then
    echo "Godot binary is not a valid 4.6.2 stable executable: $GODOT_BIN" >&2
    exit 1
  fi
}

prepare_templates() {
  if [[ -f "$TEMPLATE_DIR/web_nothreads_release.zip" && -f "$TEMPLATE_DIR/web_nothreads_debug.zip" ]]; then
    return
  fi
  mkdir -p "$TEMPLATE_DIR"

  if [[ -f "$ROOT_DIR/web_nothreads_release.zip" && -f "$ROOT_DIR/web_nothreads_debug.zip" ]]; then
    echo "Using Web export templates from repository root for $GODOT_VERSION."
    cp "$ROOT_DIR/web_nothreads_release.zip" "$TEMPLATE_DIR/web_nothreads_release.zip"
    cp "$ROOT_DIR/web_nothreads_debug.zip" "$TEMPLATE_DIR/web_nothreads_debug.zip"
    return
  fi

  cat <<MSG
Godot Web export template is missing:
  $TEMPLATE_DIR/web_nothreads_release.zip
  $TEMPLATE_DIR/web_nothreads_debug.zip

This project disables Web thread support for simpler hosting, so Godot expects
web_nothreads_* templates for $GODOT_VERSION.
MSG

  if [[ ! -f "$TEMPLATE_ARCHIVE" ]]; then
    echo "Downloading $TEMPLATE_URL"
    curl -L --fail --retry 3 --continue-at - -o "$TEMPLATE_ARCHIVE" "$TEMPLATE_URL"
  fi
  unzip -j -o "$TEMPLATE_ARCHIVE" \
    "templates/web_nothreads_release.zip" \
    "templates/web_nothreads_debug.zip" \
    "templates/web_release.zip" \
    "templates/web_debug.zip" \
    -d "$TEMPLATE_DIR"
}

prepare_godot
prepare_templates
"$GODOT_BIN" --headless --path "$ROOT_DIR" --export-release "Web" "$ROOT_DIR/index.html"

cat <<MSG

Export selesai dengan Godot $GODOT_VERSION:
  $ROOT_DIR/index.html
  $ROOT_DIR/index.js
  $ROOT_DIR/index.wasm
  $ROOT_DIR/index.pck

Jalankan:
  python3 tools/serve_web.py --directory . --port 8000
MSG
