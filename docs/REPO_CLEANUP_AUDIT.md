# Force War — Repo Cleanup Audit for Forward 3D Redesign

Tanggal audit: 2026-10-05

Tujuan audit ini: memastikan setup lama tidak ikut menjadi arah build baru. Karena user meminta **jangan coding gameplay dulu**, pass ini membersihkan dokumentasi dan mencatat file/area yang harus dibedah pada pass implementasi berikutnya.

## 1. Status Repo Saat Audit

Branch kerja:

```text
arena/01a100ae-force-war
```

Visual lock baru:

```text
gameplay_visual_lock_build.jpg
```

Reset/clean dilakukan ke head remote terbaru sebelum audit sehingga workspace tidak membawa checkout stale.

## 2. Setup Lama yang Harus Dihapus dari Direction

### 2.1 Gameplay lama di code

File utama yang masih menyimpan logika lama:

```text
scripts/main.gd
```

Area lama yang terdeteksi:

- `DIRECT_SKY_FORCE_MODE` masih mempertahankan banyak branch lama.
- `car_defs`, `selected_car`, `ground_car_*`, dan `start_ground_phase()` masih ada.
- `convoy`, `make_convoy_vehicle()`, `damage_convoy()`, `convoy_center()`, dan route/escort logic masih ada.
- Texture loading masih memuat PNG player/enemy/convoy/background untuk gameplay lama.
- Banyak function draw masih berbasis canvas 2D/top-down.
- Save key masih memakai nama lama `force-war-storm-convoy-v2`.

Keputusan: **jangan diperluas lagi**. Pada pass coding berikutnya, file ini harus dipotong/dipecah sehingga gameplay utama menjadi `ForwardAirScene3D`.

### 2.2 Asset lama yang masih ada

Asset legacy yang tidak boleh menjadi gameplay final:

```text
assets/rendered/player_stormhawk.png
assets/rendered/enemy_*.png
assets/rendered/background_*.png
assets/rendered/convoy_*.png
assets/models/player_car.glb
assets/models/enemy_car.glb
assets/models/convoy_car.glb
assets/convoy/*.svg
```

Keputusan: sementara ditandai **legacy/quarantine** sampai code rewrite selesai. Setelah tidak ada referensi runtime, file harus dihapus atau dipindah ke archive eksternal, bukan dipakai di build gameplay.

### 2.3 Dokumen lama

Dokumen lama sebelumnya masih menyebut:

- top-down aircraft gameplay;
- ground chase/prologue car;
- convoy escort sebagai objective utama;
- PNG/sprite sebagai asset gameplay utama;
- `tools/serve_web.py` dan folder `web-build` sebagai helper lama.

Keputusan pass ini: semua dokumen desain utama ditulis ulang ke arah forward 3D air combat.

## 3. Cleanup yang Dilakukan di Pass Ini

Pass ini tidak mengubah gameplay code. Cleanup yang aman dilakukan:

- README ditulis ulang ke arah **Forward Air Combat Redesign**.
- Roadmap ditulis ulang tanpa convoy/car/top-down sebagai target aktif.
- R1 code map dibuat di `docs/CODE_REBUILD_MAP.md` untuk memisahkan keep/rewrite/delete sebelum coding R2.
- Asset catalog ditulis ulang sebagai katalog GLB target + legacy quarantine.
- FX research ditulis ulang untuk third-person forward air-combat.
- UI/UX docs ditulis ulang ke flow aircraft-only.
- Web build flow dirapikan agar tetap root export/root server.
- Legacy `tools/serve_web.py` dihapus dari repo.
- Legacy asset/model generators (`tools/generate_assets.py`, `tools/generate_glb_assets.py`) dihapus supaya generator convoy/car/top-down tidak dipakai lagi.
- Legacy `web-build/README.md` dihapus dari workspace jika ada; folder `web-build/` tetap diabaikan oleh `.gitignore`.

## 4. Cleanup yang Sengaja Ditunda

Ditunda karena akan mematahkan baseline export sebelum rewrite gameplay selesai:

| Area | Alasan ditunda | Action nanti |
| --- | --- | --- |
| `scripts/main.gd` legacy convoy/car/top-down | Butuh refactor besar, bukan doc pass | Split/rewrite ke ForwardAirScene3D |
| PNG gameplay assets | Masih direferensikan code baseline | Hapus setelah GLB/VFX pipeline aktif |
| Car GLB assets | Masih direferensikan code baseline | Hapus setelah ground phase code dihapus |
| Old root export `index.pck` | Mewakili build baseline terakhir | Re-export setelah implementation pass |
| Save key lama | Harus migrasi di code, bukan doc-only | Ganti ke `force-war-forward-air-v1` atau migrasi compatible |

## 5. Required Repo State Setelah Implementation Pass

Repo dianggap bersih setelah:

- tidak ada string `convoy`, `car prologue`, `ground chase`, atau `storm convoy` di gameplay docs;
- `scripts/main.gd` tidak memuat ground car phase dan convoy failure logic;
- gameplay tidak memuat `assets/rendered/player_stormhawk.png` sebagai player;
- player aircraft model adalah GLB;
- enemy/boss utama adalah GLB/3D scene;
- camera rig adalah chase camera behind/slightly above;
- root Web export direbuild dari gameplay baru;
- QA browser memastikan GLB/camera visible.

## 6. Grep Checklist Untuk Pass Berikutnya

Gunakan checklist ini sebelum commit implementation:

```bash
grep -RInE "convoy|ground chase|car prologue|top-down|storm-convoy|storm_convoy" README.md docs scripts project.godot package.json
```

Expected untuk build final: hanya boleh muncul di changelog/audit lama, bukan di active design/runtime docs.

## 7. Non-Negotiable Design Locks

- Player plane = GLB 3D.
- Camera = behind + slightly above.
- Game motion = forward into depth, not upward screen scroll.
- Visual target = cinematic storm air war from `gameplay_visual_lock_build.jpg`.
- Old convoy/car/top-down setup = deprecated and must not guide new implementation.
