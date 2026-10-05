# Force War — Web Build Flow

Target engine: **Godot 4.6.2 stable**.

Dokumen ini mempertahankan pipeline Web yang sudah benar sambil menegaskan bahwa gameplay berikutnya akan direwrite ke forward 3D air-combat. Web export tetap root repo.

## 1. Build

Preset `Web` berada di `export_presets.cfg`.

```bash
./tools/export_web.sh
```

Godot 4.6.2 membuat output root:

```text
index.html
index.js
index.wasm
index.pck
```

Root output ini tetap menjadi acceptance criteria deploy. Jangan pindahkan output ke `web-build/`.

## 2. Serve dari Root Repo

Server utama local/Vercel berada di root repo:

```bash
npm install
npm start
```

Port custom:

```bash
PORT=8000 npm start
```

`server.js` mengirim MIME dan header:

- `application/wasm` untuk `.wasm`
- `text/javascript` untuk `.js` dan `.worker.js`
- `application/octet-stream` untuk `.pck`
- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Embedder-Policy: require-corp`
- `Cross-Origin-Resource-Policy: cross-origin`
- `X-Content-Type-Options: nosniff`
- `Access-Control-Allow-Origin: *`

Selama iterasi aktif, core export artifacts memakai no-cache headers agar preview tidak tertahan versi lama.

## 3. Vercel

File deploy utama:

```text
package.json
server.js
vercel.json
.vercelignore
```

`npm run vercel-build` tidak rebuild Godot di Vercel; command itu memverifikasi export root yang sudah committed. Rebuild Godot tetap dilakukan lokal/sandbox sebelum commit.

## 4. Browser Load Sequence

1. Browser memuat `index.html`.
2. `index.html` memuat `index.js`.
3. Godot Engine mengambil `index.wasm` dan `index.pck`.
4. Runtime menjalankan `res://scenes/Main.tscn`.
5. Render berjalan ke `<canvas>` via WebGL/Compatibility renderer.

## 5. JavaScriptBridge Target

Current baseline bridge masih ada, tetapi saat rewrite forward 3D air-combat dimulai, event/state harus diganti dari terminology lama ke aircraft-only terminology.

Target event baru:

```text
ready
loading_complete
mission_briefing
mission_start
weather_update
air_corridor_selected
lock_on_acquired
weapon_overcharge
boss_incoming
boss_phase_change
boss_down
stage_clear
game_over
```

Target save key baru setelah migration:

```text
force-war-forward-air-v1
```

Catatan: save key lama tidak boleh langsung dihapus tanpa migration jika user progress masih ingin dipertahankan.

## 6. QA Browser Debug Template

QA tetap memakai `web_nothreads_debug.zip`, Playwright Core, dan `@sparticuz/chromium`:

```bash
npm install
npm run qa:web
```

Alur QA:

1. Copy debug/release web templates ke Godot 4.6.2 export templates.
2. Export debug ke folder temporary.
3. Run `server.js` dengan `STATIC_ROOT` ke export debug.
4. HEAD-check `index.html`, `index.js`, `index.wasm`, `index.pck`.
5. Launch Chromium.
6. Verifikasi canvas Godot dan `window.ForceWarBridge`.

## 7. Forward 3D QA Tambahan yang Harus Dibuat

Setelah implementation pass:

- Verify canvas is 720x1280.
- Verify a GLB player aircraft is visible in scene.
- Verify active camera is chase/behind aircraft.
- Verify game state reports `missionMode: forward_air_combat`.
- Verify no car/convoy UI appears.
- Verify WebGL canvas renders 3D scene, not only static loading/2D draw.

## 8. Repo Hygiene

- `web-build/` is ignored and not used for deploy.
- Legacy helper server under `tools/` is removed; use `server.js` only.
- Do not commit `node_modules/`, `.godot/`, or temporary debug export folders.
- Keep root export artifacts committed because Vercel serves them.
