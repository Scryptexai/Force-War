# Force War — Big Phase Rebuild Roadmap & Progress

Tanggal: 2026-10-05
Branch kerja: `arena/01a100ae-force-war`

Roadmap ini mengganti format milestone kecil per `R#`. Rebuild Force War sekarang dibagi menjadi **phase besar** yang langsung menghasilkan satu paket playable/visible, bukan potongan kecil seperti skeleton saja. Setiap phase harus cukup besar untuk dikerjakan sebagai satu target produksi yang utuh, dengan hasil yang bisa dilihat di browser.

Target akhir tetap sama: **3D forward air-combat** dengan pesawat GLB, kamera chase dari belakang-sedikit-atas, gerak maju ke depan, arena badai 3D, VFX sinematik, dan kualitas visual mengarah ke `gameplay_visual_lock_build.jpg`.

> Status jujur: gameplay rebuild belum berjalan di browser. Yang sudah selesai adalah design lock, audit repo lama, code rebuild map, dan cleanup dokumen/tool lama. Phase 1 di bawah adalah phase aktif berikutnya dan harus langsung mengerjakan fondasi gameplay forward 3D sampai bisa dilihat di preview.

---

## 1. Non-Negotiable Target

Semua phase wajib tunduk pada aturan ini:

1. **Player aircraft wajib GLB 3D**, bukan PNG/foto/static sprite.
2. **Kamera wajib chase camera**, di belakang pesawat dan sedikit di atas.
3. **Gerak game wajib maju ke depan dalam depth 3D**, bukan scroll ke atas.
4. **Arena wajib 3D layered storm battlefield**, bukan static photo/parallax 2D.
5. **Weapon VFX wajib keluar dari hardpoint model**, bukan garis canvas yang lepas dari pesawat.
6. **Tidak ada car/convoy prologue** dalam player-facing flow.
7. **Tidak ada top-down gameplay** sebagai mode utama.
8. **Web export tetap root repo**: `index.html`, `index.js`, `index.wasm`, `index.pck`.
9. **Progress tidak boleh diklaim tinggi hanya karena dokumen selesai**; harus terbukti di browser preview.

---

## 2. Progress Snapshot Sekarang

| Area | Status | Progress realistis | Catatan |
| --- | --- | ---: | --- |
| Direction lock forward 3D | Done | 100% | `THIRD_PERSON_AIR_COMBAT_REDESIGN.md` selesai. |
| Visual reference lock | Done | 100% | `gameplay_visual_lock_build.jpg` jadi mood/quality target. |
| Code rebuild map | Done | 100% | `docs/CODE_REBUILD_MAP.md` selesai. |
| Web pipeline lama | Stable baseline | 80% | Root export/server/QA masih jalan. |
| Gameplay forward 3D playable | Not started | 0% | Belum ada scene forward 3D playable. |
| Player GLB gameplay | Not started | 0% | Belum ada `player_stormhawk.glb` sebagai player. |
| Chase camera | Not started | 0% | Belum implement. |
| Arena forward 3D | Not started | 0% | Belum implement. |
| Weapon VFX hardpoint | Not started | 0% | Belum implement. |
| Enemy/Boss 3D | Not started | 0% | Belum implement. |
| Legacy cleanup fisik | Mapped only | 10% | Code/assets lama belum dihapus karena replacement belum ada. |

### Estimasi overall rebuild

```text
Forward 3D gameplay rebuild only: ±10%
Full product including existing Web pipeline/docs: ±26%
```

---

## 3. Big Phase Board

| Phase | Nama besar | Status | Output utama | Progress target setelah selesai |
| --- | --- | --- | --- | ---: |
| Phase 0 | Direction Lock, Audit, Code Map | Done | Direction baru, visual lock, code map, docs cleanup | 10% forward rebuild |
| Phase 1 | Core Forward Flight Rebuild | Active Next | Scene 3D playable: player GLB, chase camera, forward controls, initial browser preview | 30–35% forward rebuild |
| Phase 2 | Cinematic Arena & Weather Battlefield | Planned | Arena 3D berlapis, storm clouds, warzone below, weather gameplay awal | 50–55% forward rebuild |
| Phase 3 | Weapon, Enemy, Boss Combat Package | Planned | Hardpoint weapons, enemy GLB waves, boss dreadnought, readable attack patterns | 70–75% forward rebuild |
| Phase 4 | UI/UX, Progression, Legacy Cleanup | Planned | HUD forward flight, hangar aircraft-only, save migration, old code/assets removed | 85–90% forward rebuild |
| Phase 5 | Web QA, Optimization, Content Expansion | Planned | Export final slice, browser QA, tuning, content expansion | 100% first rebuilt vertical slice |

---

## 4. Phase 0 — Direction Lock, Audit, Code Map

**Status:** Done
**Purpose:** mengunci arah baru dan mencegah setup lama masuk lagi.

### Scope yang sudah selesai

- [x] Visual target `gameplay_visual_lock_build.jpg` dikunci sebagai reference.
- [x] Direction baru ditulis: `docs/THIRD_PERSON_AIR_COMBAT_REDESIGN.md`.
- [x] Repo cleanup audit dibuat: `docs/REPO_CLEANUP_AUDIT.md`.
- [x] Code rebuild map dibuat: `docs/CODE_REBUILD_MAP.md`.
- [x] README, roadmap, asset catalog, FX research, UI/UX docs, dan Web flow docs diarahkan ulang.
- [x] Tool lama yang mendorong SVG/convoy/car/top-down workflow dihapus.

### Hasil Phase 0

- Arah lama resmi deprecated.
- `scripts/main.gd` sudah dipetakan: keep/rewrite/delete.
- Next work tidak lagi random patch, tapi masuk Phase 1 besar.

### Yang belum boleh diklaim

- Belum ada gameplay 3D forward playable.
- Belum ada player GLB aktif sebagai gameplay player.
- Belum ada chase camera baru.

---

## 5. Phase 1 — Core Forward Flight Rebuild

**Status:** Active Next
**Tujuan besar:** dalam satu phase ini, build lama harus berubah menjadi **awal playable forward 3D flight**. Phase ini tidak boleh berhenti hanya di skeleton kosong; harus sampai terlihat di browser: pesawat GLB dari kamera belakang-sedikit-atas, bergerak maju dalam corridor.

### Scope Phase 1

#### 1.1 Scene foundation

- [ ] Buat `scripts/forward_air_scene_3d.gd`.
- [ ] Tambah `ForwardAirScene3D` sebagai child runtime dari current main shell.
- [ ] Tambah `WorldEnvironment`, fog/sky storm color, `DirectionalLight3D`.
- [ ] Tambah `CameraRig3D` + `Camera3D`.
- [ ] Set world convention: forward = `-Z`.
- [ ] Tambah bridge state:
  - `missionMode: forward_air_combat`
  - `cameraMode: chase_behind_above`
  - `playerModel: glb`

#### 1.2 Player GLB placeholder/final first pass

- [ ] Buat/import `assets/models/player_stormhawk.glb`.
- [ ] Kalau final asset belum siap, buat procedural GLB placeholder yang tetap 3D nyata.
- [ ] Model minimal harus punya fuselage, wings, cockpit, tail, engine sockets, hardpoint sockets.
- [ ] Material awal: dark metal, cyan emissive strips, canopy glass.
- [ ] Tambah `PlayerRig3D` dan pasang model ke scene.

#### 1.3 Chase camera feel

- [ ] Kamera berada di belakang dan sedikit di atas player.
- [ ] Kamera melihat ke depan jalur, bukan ke bawah/top-down.
- [ ] Player berada lower third layar 9:16.
- [ ] Tambah camera lag halus.
- [ ] Tambah roll influence ringan saat player strafe.
- [ ] Tambah FOV kick placeholder untuk boost.

#### 1.4 Forward flight controls

- [ ] Konversi input ke corridor 3D:
  - X = strafe kiri/kanan;
  - Y = altitude/dodge naik-turun;
  - forward motion = world/chunks bergerak terhadap player atau player bergerak `-Z`.
- [ ] Touch drag mengontrol X/Y corridor.
- [ ] Keyboard WASD/arrow tetap bisa testing.
- [ ] Clamp corridor supaya mobile readable.
- [ ] Tambah roll/pitch visual pada player model.

#### 1.5 Minimal forward motion proof

- [ ] Tambah beberapa debug corridor markers/air lane rings di depan.
- [ ] Tambah placeholder cloud/terrain/debris simple 3D yang bergerak dari depan ke belakang untuk membuktikan maju.
- [ ] Matikan top-down gameplay renderer saat mission forward aktif.
- [ ] Pastikan tidak ada car/convoy UI di flow launch.

#### 1.6 Browser proof

- [ ] Godot check/import.
- [ ] Export Web root.
- [ ] `npm run vercel-build`.
- [ ] `npm run qa:web`.
- [ ] Restart preview.
- [ ] Ambil/cek visual: GLB player + camera belakang + forward motion.

### Deliverable Phase 1

Satu build playable awal yang membuktikan:

```text
Loading/Title/Briefing -> Launch -> 3D forward flight scene
player GLB visible
camera behind/slightly above
movement in 3D corridor
forward depth readable
old top-down gameplay not visible
```

### Acceptance Gate Phase 1

Phase 1 tidak selesai sebelum semua ini true:

- [ ] Browser menunjukkan `ForwardAirScene3D`.
- [ ] Player aircraft adalah GLB/model 3D, bukan PNG.
- [ ] Kamera jelas dari belakang sedikit di atas.
- [ ] Pesawat bisa digerakkan kiri/kanan/naik/turun dalam corridor.
- [ ] Ada bukti gerak maju ke depan dalam depth.
- [ ] Tidak ada car/convoy prologue.
- [ ] Tidak ada top-down player sprite sebagai gameplay utama.
- [ ] Root Web export dan browser QA pass.

### Progress setelah Phase 1 selesai

Jika Phase 1 lolos acceptance, progress forward rebuild boleh naik ke **30–35%**.

---

## 6. Phase 2 — Cinematic Arena & Weather Battlefield

**Status:** Planned
**Tujuan besar:** mengubah forward scene Phase 1 dari corridor kosong menjadi **arena perang badai 3D hidup** sesuai visual lock.

### Scope Phase 2

#### 2.1 Forward arena director

- [ ] Buat `scripts/forward_arena_director.gd`.
- [ ] Buat system chunk spawn/despawn di depan kamera.
- [ ] Rework `air_cloud_cluster.glb` atau buat cloud bank GLB baru.
- [ ] Rework `air_arena_tile.glb` menjadi arena forward chunks, bukan tile top-down.
- [ ] Tambah ocean/city warzone layer di bawah jalur terbang.

#### 2.2 Layered battlefield depth

- [ ] Far storm sky layer bergerak lambat.
- [ ] Mid cloud banks bergerak medium.
- [ ] Near debris/smoke streak bergerak cepat.
- [ ] Warzone below bergerak perspektif.
- [ ] Distant air traffic: ally/enemy silhouettes, tracer lines, tiny explosions.

#### 2.3 Weather as gameplay volume

- [ ] Wind field mempengaruhi smoke/trails dan sedikit steering/turbulence.
- [ ] Cloud volume menyembunyikan musuh/target marker sampai dekat atau radar aktif.
- [ ] Rain sheets menurunkan visibility.
- [ ] Lightning flash menerangi arena dan men-trigger overcharge placeholder.
- [ ] Storm cell hazard memaksa lane/altitude choice.

#### 2.4 Cinematic quality pass

- [ ] Color grading storm/sunset blue-orange.
- [ ] Light flashes and cloud edge lighting.
- [ ] Smoke columns dari warzone bawah.
- [ ] Fire pockets/explosions ambient.
- [ ] Speed tuning supaya terasa maju tapi tidak terlalu cepat.

### Deliverable Phase 2

Build browser yang memperlihatkan:

```text
3D forward flight through storm battlefield
cloud depth + warzone below + smoke/fire + debris
weather starts affecting movement/visibility/VFX
arena no longer feels empty or flat
```

### Acceptance Gate Phase 2

- [ ] Minimal 4 depth layers terlihat jelas.
- [ ] Arena bukan static photo dan bukan flat tile scroll.
- [ ] Weather punya efek gameplay awal, bukan overlay dekoratif.
- [ ] Kecepatan forward readable dan tidak terlalu cepat.
- [ ] Browser QA pass.

### Progress setelah Phase 2 selesai

Forward rebuild boleh naik ke **50–55%**.

---

## 7. Phase 3 — Weapon, Enemy, Boss Combat Package

**Status:** Planned
**Tujuan besar:** membuat combat yang terasa seperti visual target: tembakan player kuat, enemy/boss 3D, projectile readable, dan boss dreadnought sebagai anchor besar di depan.

### Scope Phase 3

#### 3.1 Weapon VFX director

- [ ] Buat `scripts/weapon_vfx_director.gd`.
- [ ] Main cannon cyan/white dari nose/inner hardpoints.
- [ ] Wing cannon bolt tebal dari wing hardpoints.
- [ ] Micro missile model + smoke trail dari missile sockets.
- [ ] Overcharge lightning laser dari nose/spine hardpoint.
- [ ] Engine exhaust permanen dengan boost flare.
- [ ] Hit sparks, debris, smoke on impact.

#### 3.2 Enemy director 3D

- [ ] Buat `scripts/enemy_director_3d.gd`.
- [ ] Enemy fighter/drone/gunship GLB placeholder.
- [ ] Spawn enemy di depth depan, bukan dari top screen 2D.
- [ ] Attack patterns red/orange readable:
  - lane fire;
  - fan fire;
  - missile warning;
  - slow beam telegraph.
- [ ] No constant unfair homing.

#### 3.3 Boss dreadnought set piece

- [ ] Buat/import `assets/models/boss_dreadnought_leviathan.glb` placeholder.
- [ ] Boss berada upper-middle depth, bukan top overlay image.
- [ ] Tambah central weather cannon.
- [ ] Tambah turret hardpoints.
- [ ] Tambah weakpoint lights.
- [ ] Tambah shield/phase placeholder.
- [ ] Tambah boss laser charge telegraph.

#### 3.4 Combat feedback

- [ ] Enemy hit flash/damage state.
- [ ] Boss turret sparks/smoke.
- [ ] Camera shake/FOV for heavy shots.
- [ ] Score/combo hooks.
- [ ] Death/explosion first pass.

### Deliverable Phase 3

Build browser yang memperlihatkan:

```text
player GLB fires strong cyan hardpoint weapons
enemy GLB waves attack with red/orange patterns
boss dreadnought appears in 3D ahead
laser/missile/explosion VFX readable
```

### Acceptance Gate Phase 3

- [ ] Player fire tidak lagi terlihat seperti 2 peluru lemah.
- [ ] Shots lahir dari hardpoints model.
- [ ] Enemy dan boss adalah 3D scene/model.
- [ ] Boss attack punya telegraph/safe gaps.
- [ ] Hit impact membuat combat terasa berat.
- [ ] Browser QA pass.

### Progress setelah Phase 3 selesai

Forward rebuild boleh naik ke **70–75%**.

---

## 8. Phase 4 — UI/UX, Progression, Legacy Cleanup

**Status:** Planned
**Tujuan besar:** membuat build baru bersih dari setup lama, UI cocok forward flight, progression aircraft-only, dan repo tidak lagi membawa runtime car/convoy/top-down.

### Scope Phase 4

#### 4.1 HUD forward flight

- [ ] Center reticle/crosshair.
- [ ] Lock-on bracket/ring.
- [ ] Boss bar top-center.
- [ ] HP/shield top-left.
- [ ] Score/combo top-right.
- [ ] Ability buttons thumb-safe.
- [ ] Radar/weather mini-map bottom-right.
- [ ] Warning marker untuk missile/storm cell.

#### 4.2 Aircraft-only hangar/progression

- [ ] Remove car tab from UI.
- [ ] Aircraft preview uses GLB turntable or strong placeholder.
- [ ] Upgrade categories:
  - main cannon;
  - wing cannon;
  - missiles;
  - armor/shield;
  - engine/handling;
  - storm systems.
- [ ] Save schema migrates to `force-war-forward-air-v1`.
- [ ] Old `storm_convoy` save can be migrated or ignored safely.

#### 4.3 Legacy code cleanup

- [ ] Remove ground car phase code.
- [ ] Remove convoy logic and events.
- [ ] Remove top-down gameplay renderer as runtime mode.
- [ ] Remove old car/convoy active assets after grep confirms no references.
- [ ] Remove runtime dependency on `assets/rendered/player_stormhawk.png` for player.
- [ ] Update docs after physical cleanup.

#### 4.4 Loading/branding cleanup

- [ ] Loading slideshow must match aircraft-only storm war direction.
- [ ] Remove/regenerate visible convoy/car loading art if mismatch.
- [ ] Keep Force War splash/icon branding.

### Deliverable Phase 4

Build yang sudah bersih secara player-facing dan repo runtime:

```text
aircraft-only forward combat flow
forward flight HUD
aircraft-only hangar/progression
old car/convoy/top-down code removed or fully inactive
```

### Acceptance Gate Phase 4

- [ ] No car/convoy UI appears anywhere active.
- [ ] No top-down gameplay path active.
- [ ] Save/progression aircraft-only works.
- [ ] Grep forbidden runtime functions clear except audit/changelog docs.
- [ ] Browser QA pass.

### Progress setelah Phase 4 selesai

Forward rebuild boleh naik ke **85–90%**.

---

## 9. Phase 5 — Web QA, Optimization, Content Expansion

**Status:** Planned
**Tujuan besar:** menjadikan rebuilt vertical slice stabil, teroptimasi Web, dan cukup berisi untuk dinilai sebagai serious direction, bukan prototype kecil.

### Scope Phase 5

#### 5.1 Web export and QA hardening

- [ ] Godot check-only.
- [ ] Godot import.
- [ ] `./tools/export_web.sh`.
- [ ] `npm run vercel-build`.
- [ ] `npm run qa:web`.
- [ ] Add visual QA for:
  - GLB player visible;
  - chase camera active;
  - mission mode forward air combat;
  - no old UI;
  - WebGL rendering 3D scene.

#### 5.2 Performance optimization

- [ ] Check Web FPS/perceived smoothness.
- [ ] Reduce overdraw/particles if needed.
- [ ] Compress/size GLB assets.
- [ ] Keep root export reasonable.
- [ ] Avoid giant generated artifacts in git.

#### 5.3 Content expansion for first rebuilt slice

- [ ] 2–4 player aircraft GLB variants or visual variants.
- [ ] 4–6 enemy GLB types.
- [ ] 1 polished boss dreadnought + at least 2 attack phases.
- [ ] 2–3 arena biomes or biome variants.
- [ ] Weather forecast/loadout matters in mission.
- [ ] Audio placeholder or procedural first pass if scope allows.

#### 5.4 Tuning and polish

- [ ] Movement speed/camera comfort.
- [ ] Weapon density/readability.
- [ ] Enemy damage/safe gaps.
- [ ] Boss HP/duration.
- [ ] HUD readability on 720x1280.
- [ ] Touch controls.

### Deliverable Phase 5

First rebuilt vertical slice:

```text
Force War forward 3D air combat playable in browser
GLB player + chase camera + forward arena + weather + weapons + enemies + boss
root Web export updated
QA passed
```

### Acceptance Gate Phase 5

- [ ] User can open preview and immediately see the new gameplay form.
- [ ] It no longer resembles the rejected top-down/static/old setup.
- [ ] Web export root files are current.
- [ ] Browser QA pass.
- [ ] Roadmap/progress updated honestly.

### Progress setelah Phase 5 selesai

Forward rebuilt vertical slice boleh disebut **100% for first rebuilt slice**, bukan full commercial game.

---

## 10. Active Work Order Sekarang

Karena user meminta phase besar, next work bukan “R2 skeleton” terpisah. Next work adalah:

```text
Phase 1 — Core Forward Flight Rebuild
```

Urutan kerja Phase 1:

1. Buat `forward_air_scene_3d.gd`.
2. Generate/import `player_stormhawk.glb` placeholder 3D nyata.
3. Spawn `ForwardAirScene3D` dari current main shell.
4. Pasang chase camera behind/slightly above.
5. Pasang player GLB lower-third portrait framing.
6. Implement movement X/Y corridor + roll/pitch.
7. Tambah minimal forward lane/depth markers/cloud placeholders.
8. Matikan old top-down renderer saat forward scene active.
9. Export Web + QA + preview.

Phase 1 tidak selesai sampai browser memperlihatkan player GLB dari chase camera.

---

## 11. Progress Update Template untuk Phase Besar

Gunakan template ini setiap selesai commit besar:

```text
Phase: Phase # — Name
Status: Not started / Active / Blocked / Done
Changed files:
Validation run:
Visible result in browser:
Acceptance checklist passed:
What remains incomplete:
Next work inside same phase or next phase:
```

---

## 12. Do Not Claim Done Until

Jangan mark phase selesai jika hanya dokumen/code skeleton. Phase selesai hanya kalau acceptance gate-nya terlihat/tervalidasi.

Khusus Phase 1, jangan klaim selesai sampai:

- player GLB terlihat;
- kamera chase terlihat;
- forward movement terbaca;
- top-down renderer tidak muncul di gameplay;
- Web QA pass.
