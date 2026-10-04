# Alur Teknis Web Build Force War: Storm Convoy

Target engine: **Godot 4.6.2 stable**.

## 1. Build

Preset `Web` berada di `export_presets.cfg`.

```bash
./tools/export_web.sh
```

Godot 4.6.2 akan membuat:

```text
index.html
index.js
index.wasm
index.pck
```

`index.pck` berisi resource project: scene, GDScript terkompilasi, SVG imported textures, konfigurasi, dan icon.

## 2. Serve dari Root Repo/Home Directory

Server utama untuk local preview dan Vercel flow berada di root repo, bukan di folder `tools/`:

```bash
npm install
npm start
```

Port custom:

```bash
PORT=8000 npm start
```

`server.js` mengirim MIME dan header berikut:

- `application/wasm` untuk `.wasm`
- `text/javascript` untuk `.js` dan `.worker.js`
- `application/octet-stream` untuk `.pck`
- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Embedder-Policy: require-corp`
- `Cross-Origin-Resource-Policy: cross-origin`
- `X-Content-Type-Options: nosniff`
- `Access-Control-Allow-Origin: *`

## 2.5. Vercel

File konfigurasi deployment:

- `package.json` — membuat Vercel otomatis mengenali project Node/npm dan menyediakan `npm start`, `npm run vercel-build`, `npm run qa:web`.
- `server.js` — server root yang sama untuk local preview.
- `vercel.json` — header COOP/COEP/CORP dan MIME untuk `.wasm`, `.pck`, `.js`.
- `.vercelignore` — menghindari upload Godot binary/template/source besar; Web runtime cukup memakai `index.*`.

`npm run vercel-build` tidak rebuild Godot di Vercel; ia memverifikasi export root yang sudah committed. Rebuild Godot tetap dilakukan sebelum commit dengan Godot 4.6.2.

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

## 6. QA Browser Debug Template

QA debug memakai `web_nothreads_debug.zip` yang ada di root repo dan Playwright Core + `@sparticuz/chromium`:

```bash
npm install
npm run qa:web
```

Alur QA:

1. Pastikan `web_nothreads_debug.zip` dan `web_nothreads_release.zip` tersedia.
2. Copy template ke folder export template Godot 4.6.2.
3. Export debug ke folder temporary.
4. Run `server.js` dari root repo dengan `STATIC_ROOT` ke export debug.
5. HEAD-check `index.html`, `index.js`, `index.wasm`, `index.pck` beserta COOP/COEP.
6. Launch Chromium melalui Playwright Core + `@sparticuz/chromium`.
7. Verifikasi canvas Godot dan `window.ForceWarBridge`.
