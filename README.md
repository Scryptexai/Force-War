# Force War: Storm Convoy

Force War: Storm Convoy adalah tactical vertical escort shooter original untuk **Godot 4.6.2 stable** dan Web export. Fokus game bukan hanya membunuh semua musuh, tetapi **mengawal konvoi darat** melewati rute bercabang di tengah cuaca ekstrem.

## Konsep Utama

Kamu adalah pilot support-combat yang menjaga konvoi di bawah. Konvoi punya beberapa kendaraan dengan HP sendiri-sendiri: command truck, fuel tanker, APC, dan supply truck. Stage selesai jika konvoi mencapai ekstraksi dan blockade/boss dihancurkan. Stage gagal jika konvoi hancur atau pesawat pemain jatuh.

### Yang membedakan dari shooter pasaran

- **Objektif proteksi:** konvoi adalah pusat misi, bukan kill count.
- **Rute bercabang:** di tengah stage kamu memilih jalur aman/lambat, jalur cepat/berisiko, atau jalur badai dengan reward tinggi.
- **Cuaca sebagai puzzle:** angin membelokkan peluru, awan menyembunyikan musuh, hujan menurunkan visibility, flood memperlambat konvoi, petir bisa overcharge senjata atau menghancurkan unit.
- **Loadout berdasarkan forecast:** sebelum stage pilih paket support yang cocok dengan prakiraan cuaca.
- **Support tools:** repair pod, smoke screen, supply drop, radar flare, lightning rod.

## Status Produksi Saat Ini

Sudah dibuat:

- Roadmap full version: `docs/ROADMAP.md`
- Asset catalog: `docs/ASSET_CATALOG.md`
- SVG asset generator: `tools/generate_assets.py`
- Asset original untuk player, musuh udara, musuh darat, konvoi, support pod, dan weather icon di `assets/`
- Gameplay escort di `scripts/main.gd`:
  - 6 operation campaign skeleton
  - multi-vehicle convoy HP
  - route branching
  - weather systems
  - air + ground enemies
  - support drops
  - boss/blockade
  - Web `JavaScriptBridge` state/events
  - local save/localStorage
- Godot Web preset: `export_presets.cfg`
- Build script Godot 4.6.2: `tools/export_web.sh`
- Python web server: `tools/serve_web.py`

## Kontrol

| Aksi | Tombol |
| --- | --- |
| Gerak | WASD / Arrow |
| Touch/mobile | Drag layar |
| Pause | P |
| Pilih loadout di briefing | ← / → |
| Pilih stage di briefing | ↑ / ↓ |
| Launch / confirm route | Enter / Space |
| Route choice | ← / → lalu Enter |
| Repair pod | 1 |
| Smoke screen | 2 |
| Supply drop | 3 |
| Radar flare | 4 |
| Lightning rod | 5 |
| Abort/back | Esc |

## Struktur Penting

```text
project.godot                         # Konfigurasi Godot 4.6.2
scenes/Main.tscn                      # Main scene
scripts/main.gd                       # Gameplay escort, route, weather, combat, JS bridge
assets/                               # SVG game assets original
assets/*/*.svg.import                 # Godot import metadata
tools/generate_assets.py              # Deterministic SVG asset generator
tools/export_web.sh                   # Export Web dengan Godot 4.6.2
tools/serve_web.py                    # Server Python dengan header WebAssembly
docs/ROADMAP.md                       # Roadmap full version
docs/ASSET_CATALOG.md                 # Daftar asset dan fungsi gameplay
docs/WEB_BUILD_FLOW.md                # Alur teknis Web build
web-build/                            # Output index.html/js/wasm/pck setelah export
```

## Godot 4.6.2 Stable

Target resmi:

```text
Godot_v4.6.2-stable_linux.x86_64.zip
```

Link resmi:

```text
https://github.com/godotengine/godot-builds/releases/download/4.6.2-stable/Godot_v4.6.2-stable_linux.x86_64.zip
```

Export templates resmi:

```text
https://github.com/godotengine/godot-builds/releases/download/4.6.2-stable/Godot_v4.6.2-stable_export_templates.tpz
```

Project ini memakai Web no-thread template:

```text
~/.local/share/godot/export_templates/4.6.2.stable/web_nothreads_release.zip
~/.local/share/godot/export_templates/4.6.2.stable/web_nothreads_debug.zip
```

Jika `web_nothreads_release.zip` dan `web_nothreads_debug.zip` ada di root repo, `tools/export_web.sh` otomatis menyalinnya ke folder template Godot 4.6.2.

> Catatan sandbox: file `godot_v4.6.2-stable-linux_release.x86_64` yang ada dari main branch saat ini terdeteksi invalid/truncated di sandbox (`Bus error`). Ganti dengan zip/binary resmi Godot 4.6.2 agar export CLI bisa berjalan penuh.

## Generate Assets

```bash
./tools/generate_assets.py
```

Script ini regenerate semua SVG asset di `assets/` secara deterministik.

## Build Web

```bash
./tools/export_web.sh
```

Output yang diharapkan:

```text
web-build/index.html
web-build/index.js
web-build/index.wasm
web-build/index.pck
```

## Serve Web Build

```bash
python3 tools/serve_web.py --directory web-build --port 8000
```

Server bind ke `0.0.0.0` dan mengirim header penting:

- `.wasm` → `application/wasm`
- `.js` → `text/javascript`
- `.pck` → `application/octet-stream`
- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Embedder-Policy: require-corp`
- `X-Content-Type-Options: nosniff`

## Alur Teknis Web

1. **Build:** Godot 4.6.2 mengekspor proyek ke `index.html`, `index.js`, `index.wasm`, `index.pck`.
2. **Serve:** `tools/serve_web.py` mengirim file dengan MIME `application/wasm` dan security headers.
3. **Load:** Browser memuat `index.html`; `index.js` menginisialisasi engine; `index.wasm` dieksekusi.
4. **Render:** Godot Web runtime menggambar ke `<canvas>` melalui WebGL 2.0/Compatibility renderer.
5. **Interaksi:** `JavaScriptBridge` menulis state/event game ke `window.ForceWarBridge` dan menyimpan progress ke `localStorage`.

Contoh browser console:

```js
window.addEventListener('force-war-event', (event) => console.log(event.detail));
console.log(window.ForceWarBridge.state);
```

## Validasi Cepat

Dengan binary Godot valid:

```bash
godot --headless --path . --check-only --script scripts/main.gd
godot --headless --path . --import
godot --headless --path . --quit-after 10
```
