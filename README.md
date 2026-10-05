# Force War: Forward Air Combat Redesign

Force War sekarang **dikunci ulang arahnya** menjadi game **3D forward air-combat** untuk Godot 4.6.2 stable dan Web export. Arah lama berupa vertical/top-down aircraft canvas, prologue mobil/konvoi, dan gameplay berbasis PNG/static sprite **tidak lagi menjadi target desain**.

> Status jujur: commit saat ini masih membawa build lama sebagai baseline teknis/Web export. Dokumen ini adalah redesign lock sebelum implementasi berikutnya. Gameplay final yang diinginkan harus mengganti build lama dengan pesawat GLB 3D, kamera chase dari belakang-sedikit-atas, dan arena perang yang bergerak maju ke depan.

## Visual Lock

Referensi visual internal yang dikunci:

```text
gameplay_visual_lock_build.jpg
```

Gambar ini dipakai sebagai **mood/quality target**, bukan sebagai asset gameplay statis. Targetnya adalah rasa perang udara sinematik: player jet besar di foreground, boss/dreadnought jauh di depan, laser, rudal, smoke trail, ledakan, awan badai, dan UI mobile 9:16.

## Arah Gameplay Baru

- **Pesawat player harus GLB 3D**, bukan foto/PNG statis.
- **Enemy aircraft, drone, turret, missile, dan boss utama juga diarahkan ke GLB/3D**, bukan sprite top-down.
- **Kamera chase 3D:** kamera di belakang pesawat, sedikit di atas, melihat ke arah depan lintasan.
- **Game bergerak maju ke depan**, bukan scroll ke atas pada canvas 2D.
- **Player mengontrol posisi dalam flight corridor**: strafe kiri/kanan, naik/turun sedikit, dodge roll/boost, dan lock-on/aim ke target di depan.
- **Arena adalah world 3D berlapis:** storm clouds, ocean/city warzone di bawah, debris, smoke columns, ally/enemy traffic, boss carrier di depan.
- **Cuaca tetap menjadi sistem gameplay:** wind drift, cloud concealment, rain visibility, lightning overcharge, storm hazards.
- **UI tetap mobile portrait 9:16**, tetapi gameplay di bawahnya adalah 3D chase/rail-forward shooter.

## Yang Tidak Boleh Masuk Lagi ke Build Baru

- Tidak ada car/convoy prologue.
- Tidak ada gameplay top-down sebagai mode utama.
- Tidak ada pesawat player sebagai foto/PNG statis.
- Tidak ada arena berupa static photo/parallax 2D.
- Tidak ada dokumentasi yang mengklaim setup convoy/car/top-down sebagai direction aktif.
- File legacy boleh sementara ada hanya jika masih dibutuhkan untuk menjaga baseline lama sampai rewrite selesai, tetapi harus ditandai deprecated dan dijadwalkan hapus.

## Dokumen Desain Baru

```text
docs/THIRD_PERSON_AIR_COMBAT_REDESIGN.md  # Target kamera, gameplay, arena, VFX, benchmark
docs/REBUILD_ROADMAP_AND_MILESTONES.md    # Big phase rebuild roadmap + progress gates
docs/PHASE_0_DIRECTION_LOCK_REPORT.md     # Phase 0 completion report and Phase 1 entry gate
docs/PHASE_1_CORE_FORWARD_FLIGHT_REPORT.md     # Phase 1 GLB/chase-camera forward flight completion report
docs/PHASE_2_CINEMATIC_ARENA_WEATHER_REPORT.md     # Phase 2 layered storm battlefield and weather gameplay report
docs/CODE_REBUILD_MAP.md                  # Phase 1 prep map: keep/rewrite/delete + cut points
docs/REPO_CLEANUP_AUDIT.md                # Audit setup lama dan daftar bersih-bersih repo
docs/ROADMAP.md                           # Roadmap baru tanpa convoy/car/top-down sebagai target
docs/ASSET_CATALOG.md                     # Katalog asset target GLB + legacy quarantine
docs/FX_RESEARCH.md                       # Riset VFX forward air-combat
docs/UI_UX_FLOW_AUDIT.md                  # Flow mobile baru
docs/UI_UX_RESEARCH.md                    # Prinsip UX baru untuk forward air-combat
docs/WEB_BUILD_FLOW.md                    # Web export/root server flow yang tetap dipertahankan
```

## Struktur Penting

```text
project.godot                         # Konfigurasi Godot 4.6.2, viewport 720x1280
scenes/Main.tscn                      # Main scene baseline saat ini; akan dirombak ke 3D chase air scene
scripts/main.gd                       # Baseline gameplay lama; wajib dibedah pada pass implementasi berikutnya
assets/models/                        # Target utama asset gameplay baru: GLB pesawat, enemy, boss, arena chunks
assets/rendered/                      # Hanya untuk logo/loading/UI reference; tidak boleh menjadi player aircraft gameplay final
gameplay_visual_lock_build.jpg        # Visual target reference, bukan gameplay texture
tools/export_web.sh                   # Export Web Godot 4.6.2 ke root repo
server.js                             # Root Node server untuk local/Vercel WebAssembly headers
package.json                          # npm start / qa:web / vercel-build
vercel.json                           # Header COOP/COEP/MIME untuk deploy Vercel
index.html / index.js / index.wasm / index.pck  # Output Web di root repo
```

## Godot 4.6.2 Stable

Target engine tetap:

```text
Godot_v4.6.2-stable_linux.x86_64.zip
```

Official binary:

```text
https://github.com/godotengine/godot-builds/releases/download/4.6.2-stable/Godot_v4.6.2-stable_linux.x86_64.zip
```

Official export templates:

```text
https://github.com/godotengine/godot-builds/releases/download/4.6.2-stable/Godot_v4.6.2-stable_export_templates.tpz
```

Project memakai Web no-thread template:

```text
~/.local/share/godot/export_templates/4.6.2.stable/web_nothreads_release.zip
~/.local/share/godot/export_templates/4.6.2.stable/web_nothreads_debug.zip
```

## Build Web

Output Web tetap harus berada di root repo:

```bash
./tools/export_web.sh
```

Output yang diharapkan:

```text
index.html
index.js
index.wasm
index.pck
```

## Serve Web Build dari Root Repo

```bash
npm install
npm start
```

Port custom:

```bash
PORT=8000 npm start
```

`server.js` bind ke `0.0.0.0` dan mengirim header penting untuk Godot Web/WebAssembly.

## QA Web

```bash
npm run vercel-build
npm run qa:web
```

Catatan: QA Web memvalidasi pipeline browser/canvas/runtime. Setelah rewrite gameplay 3D chase dimulai, QA visual tambahan harus ditambah untuk memastikan kamera, GLB pesawat, dan arena forward benar-benar muncul di browser.
