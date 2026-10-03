# Alur Teknis Web Build Force War: Storm Convoy

Target engine: **Godot 4.6.2 stable**.

## 1. Build

Preset `Web` berada di `export_presets.cfg`.

```bash
./tools/export_web.sh
```

Godot 4.6.2 akan membuat:

```text
web-build/index.html
web-build/index.js
web-build/index.wasm
web-build/index.pck
```

`index.pck` berisi resource project: scene, GDScript terkompilasi, SVG imported textures, konfigurasi, dan icon.

## 2. Serve

```bash
python3 tools/serve_web.py --directory web-build --port 8000
```

Server mengirim MIME dan header berikut:

- `application/wasm` untuk `.wasm`
- `text/javascript` untuk `.js` dan `.worker.js`
- `application/octet-stream` untuk `.pck`
- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Embedder-Policy: require-corp`
- `Cross-Origin-Resource-Policy: cross-origin`
- `X-Content-Type-Options: nosniff`
- `Access-Control-Allow-Origin: *`

## 3. Load

Urutan browser:

1. Memuat `index.html`.
2. `index.html` memuat `index.js`.
3. `index.js` membuat instance Godot Engine.
4. Engine mengambil `index.wasm` dan `index.pck`.
5. Runtime menjalankan main scene `res://scenes/Main.tscn`.

## 4. Render

`project.godot` mengatur renderer ke `gl_compatibility`, target yang cocok untuk Web. Saat diekspor ke Web, Godot menggambar ke elemen `<canvas>` browser melalui WebGL 2.0/Compatibility renderer.

## 5. Interaksi JavaScriptBridge

`scripts/main.gd` memakai singleton `JavaScriptBridge` saat `OS.has_feature("web")` aktif.

Game menulis state ke:

```js
window.ForceWarBridge.state
window.ForceWarBridge.lastEvent
window.ForceWarBridge.events
```

Game juga mengirim event browser:

```js
window.dispatchEvent(new CustomEvent('force-war-event', { detail: payload }));
```

Event penting:

- `ready`
- `stage_start`
- `route_split`
- `route_selected`
- `support_drop`
- `lightning`
- `boss_incoming`
- `boss_down`
- `convoy_vehicle_destroyed`
- `stage_clear`
- `game_over`

Contoh integrasi halaman host:

```js
window.addEventListener('force-war-event', (event) => {
  console.log('Force War event:', event.detail);
});

setInterval(() => {
  console.log(window.ForceWarBridge?.state);
}, 1000);
```

Save Web disimpan ke `localStorage` key:

```text
force-war-storm-convoy-v2
```
