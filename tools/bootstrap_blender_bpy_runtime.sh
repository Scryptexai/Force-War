#!/usr/bin/env bash
set -euo pipefail

# Bootstrap a headless Blender Python runtime for restricted CI/sandbox machines
# where the official Blender binary cannot be downloaded via apt/blender.org.
# This uses the official `bpy` wheel, then provides tiny headless loader stubs for
# graphics libraries that are linked but not used by the GLB import/export path.

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR="${FORCE_WAR_BPY_VENV:-/tmp/forcewar-bpy-venv}"
LIB_DIR="${FORCE_WAR_BPY_LD_LIBRARY_PATH:-/tmp/forcewar-bpy-libs}"
BPy_VERSION="${FORCE_WAR_BPY_VERSION:-4.5.14}"

"$PYTHON_BIN" -m venv "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/pip" install "bpy==$BPy_VERSION"

mkdir -p "$LIB_DIR"
cat > "$LIB_DIR/stub_xfixes.c" <<'C'
void XFixesHideCursor(void* d, unsigned long w) {}
void XFixesShowCursor(void* d, unsigned long w) {}
C
cat > "$LIB_DIR/stub_xi.c" <<'C'
#include <stdlib.h>
void* XOpenDevice(void* display, unsigned long id){ return malloc(1); }
int XCloseDevice(void* display, void* device){ free(device); return 0; }
void* XListInputDevices(void* display, int* ndevices){ if(ndevices) *ndevices=0; return 0; }
void XFreeDeviceList(void* list) {}
void* XQueryDeviceState(void* display, void* device){ return 0; }
void XFreeDeviceState(void* state) {}
int XSelectExtensionEvent(void* display, unsigned long window, void* event_list, int count){ return 0; }
void* XGetExtensionVersion(void* display, const char* name){ return 0; }
int _XiGetDevicePresenceNotifyEvent(void* display){ return 0; }
C
cat > "$LIB_DIR/stub_xkb.c" <<'C'
#include <stdlib.h>
void* xkb_context_new(int flags){ return malloc(1); }
void xkb_context_unref(void* ctx){ free(ctx); }
void* xkb_keymap_new_from_string(void* ctx, const char* str, int fmt, int flags){ return malloc(1); }
void xkb_keymap_unref(void* km){ free(km); }
int xkb_keymap_mod_get_index(void* km, const char* name){ return 0; }
int xkb_keymap_key_repeats(void* km, unsigned int key){ return 0; }
void* xkb_state_new(void* km){ return malloc(1); }
void xkb_state_unref(void* st){ free(st); }
void* xkb_state_get_keymap(void* st){ return 0; }
int xkb_state_update_mask(void* st, unsigned int a,unsigned int b,unsigned int c,unsigned int d,unsigned int e,unsigned int f){ return 0; }
unsigned int xkb_state_serialize_mods(void* st, int comp){ return 0; }
unsigned int xkb_state_key_get_one_sym(void* st, unsigned int key){ return 0; }
int xkb_state_key_get_utf8(void* st, unsigned int key, char* buf, unsigned long size){ if(buf && size) buf[0]=0; return 0; }
void* xkb_compose_table_new_from_locale(void* ctx, const char* locale, int flags){ return malloc(1); }
void xkb_compose_table_unref(void* table){ free(table); }
void* xkb_compose_state_new(void* table, int flags){ return malloc(1); }
void xkb_compose_state_unref(void* state){ free(state); }
int xkb_compose_state_feed(void* state, unsigned int sym){ return 0; }
int xkb_compose_state_get_status(void* state){ return 0; }
int xkb_compose_state_get_utf8(void* state, char* buf, unsigned long size){ if(buf && size) buf[0]=0; return 0; }
void xkb_compose_state_reset(void* state) {}
C
cat > "$LIB_DIR/stub_gl.c" <<'C'
void glFinish(void) {}
void* glXChooseFBConfig(void* dpy, int screen, const int* attrib, int* nelements){ if(nelements) *nelements=0; return 0; }
void* glXCreateContext(void* dpy, void* vis, void* share, int direct){ return 0; }
void* glXCreateNewContext(void* dpy, void* config, int render_type, void* share, int direct){ return 0; }
unsigned long glXCreateWindow(void* dpy, void* config, unsigned long win, const int* attrib){ return 0; }
void glXDestroyContext(void* dpy, void* ctx) {}
void* glXGetCurrentContext(void){ return 0; }
void* glXGetCurrentDisplay(void){ return 0; }
unsigned long glXGetCurrentDrawable(void){ return 0; }
void* glXGetProcAddress(const unsigned char* name){ return 0; }
void* glXGetProcAddressARB(const unsigned char* name){ return 0; }
void* glXGetVisualFromFBConfig(void* dpy, void* config){ return 0; }
int glXMakeContextCurrent(void* dpy, unsigned long draw, unsigned long read, void* ctx){ return 0; }
int glXMakeCurrent(void* dpy, unsigned long drawable, void* ctx){ return 0; }
int glXQueryContext(void* dpy, void* ctx, int attribute, int* value){ if(value) *value=0; return 0; }
void glXSwapBuffers(void* dpy, unsigned long drawable) {}
C
cat > "$LIB_DIR/stub_empty.c" <<'C'
void __forcewar_empty_stub(void) {}
C

gcc -shared -fPIC -Wl,-soname,libXfixes.so.3 -o "$LIB_DIR/libXfixes.so.3" "$LIB_DIR/stub_xfixes.c"
gcc -shared -fPIC -Wl,-soname,libXi.so.6 -o "$LIB_DIR/libXi.so.6" "$LIB_DIR/stub_xi.c"
gcc -shared -fPIC -Wl,-soname,libxkbcommon.so.0 -o "$LIB_DIR/libxkbcommon.so.0" "$LIB_DIR/stub_xkb.c"
gcc -shared -fPIC -Wl,-soname,libGL.so.1 -o "$LIB_DIR/libGL.so.1" "$LIB_DIR/stub_gl.c"
for lib in libXrender.so.1 libSM.so.6 libICE.so.6; do
  gcc -shared -fPIC -Wl,-soname,"$lib" -o "$LIB_DIR/$lib" "$LIB_DIR/stub_empty.c"
done

LD_LIBRARY_PATH="$LIB_DIR:${LD_LIBRARY_PATH:-}" "$VENV_DIR/bin/python" - <<'PY'
import bpy
print(f"Blender bpy runtime OK: {bpy.app.version_string}")
print(f"GLTF import available: {hasattr(bpy.ops.import_scene, 'gltf')}")
print(f"GLTF export available: {hasattr(bpy.ops.export_scene, 'gltf')}")
PY

echo "FORCE_WAR_BPY_PYTHON=$VENV_DIR/bin/python"
echo "FORCE_WAR_BPY_LD_LIBRARY_PATH=$LIB_DIR"
