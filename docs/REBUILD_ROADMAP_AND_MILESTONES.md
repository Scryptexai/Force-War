# Force War — Big Phase Rebuild Roadmap & Progress

Tanggal: 2026-10-05
Branch kerja: `arena/01a100ae-force-war`

Roadmap ini mengganti format milestone kecil per `R#`. Rebuild Force War sekarang dibagi menjadi **phase besar** yang langsung menghasilkan satu paket playable/visible, bukan potongan kecil seperti skeleton saja. Setiap phase harus cukup besar untuk dikerjakan sebagai satu target produksi yang utuh, dengan hasil yang bisa dilihat di browser.

Target akhir tetap sama: **3D forward air-combat** dengan pesawat GLB, kamera chase dari belakang-sedikit-atas, gerak maju ke depan, arena badai 3D, VFX sinematik, dan kualitas visual mengarah ke `gameplay_visual_lock_build.jpg`.

> Status jujur: Phase 2 sudah menghasilkan arena perang badai 3D berlapis dengan weather gameplay awal dan browser QA. Build ini belum punya hardpoint weapon combat, enemy waves 3D, atau boss dreadnought. Phase 3 berikutnya harus membangun paket combat utama.

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
| Gameplay forward 3D playable | Phase 1 core done | 35% | `ForwardAirScene3D` aktif di browser dengan GLB player dan chase camera. |
| Player GLB gameplay | First pass done | 35% | `assets/models/player_stormhawk.glb` dipakai sebagai player placeholder 3D. |
| Chase camera | First pass done | 35% | `cameraMode: chase_behind_above` tervalidasi via browser QA. |
| Arena forward 3D | Phase 2 battlefield pass done | 55% | `ForwardArenaDirector` memberi storm sky, cloud volumes, warzone below, rain/debris/tracers, hazards. |
| Weapon VFX hardpoint | Not started | 0% | Belum implement. |
| Enemy/Boss 3D | Not started | 0% | Belum implement. |
| Legacy cleanup fisik | Mapped only | 10% | Code/assets lama belum dihapus karena replacement belum ada. |

### Estimasi overall rebuild

```text
Forward 3D gameplay rebuild only: ±52–55%
Full product including existing Web pipeline/docs: ±50–52%
```

---

## 3. Big Phase Board

| Phase | Nama besar | Status | Output utama | Progress target setelah selesai |
| --- | --- | --- | --- | ---: |
| Phase 0 | Direction Lock, Audit, Code Map | Done | Direction baru, visual lock, code map, docs cleanup | 10% forward rebuild |
| Phase 1 | Core Forward Flight Rebuild | Done | Scene 3D playable: player GLB, chase camera, forward controls, browser QA | 35% forward rebuild |
| Phase 2 | Cinematic Arena & Weather Battlefield | Done | Arena 3D berlapis, storm clouds, warzone below, weather gameplay awal, browser QA | 52–55% forward rebuild |
| Phase 3 | Weapon, Enemy, Boss Combat Package | Active Next | Hardpoint weapons, enemy GLB waves, boss dreadnought, readable attack patterns | 70–75% forward rebuild |
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
- [x] Phase 0 completion report dibuat: `docs/PHASE_0_DIRECTION_LOCK_REPORT.md`.
- [x] README, roadmap, asset catalog, FX research, UI/UX docs, dan Web flow docs diarahkan ulang.
- [x] Tool lama yang mendorong SVG/convoy/car/top-down workflow dihapus.

### Hasil Phase 0

- Arah lama resmi deprecated.
- `scripts/main.gd` sudah dipetakan: keep/rewrite/delete.
- Phase 1 entry gate sudah jelas: build forward 3D playable dengan GLB player dan chase camera.

### Yang saat itu belum boleh diklaim

- Gameplay 3D forward playable, player GLB aktif, dan chase camera baru baru boleh diklaim setelah Phase 1 browser QA pass. Phase 1 report sekarang mencatat gate ini sudah lolos.

---

## 5. Phase 1 — Core Forward Flight Rebuild

**Status:** Done for first playable forward-flight core
**Tujuan besar:** dalam satu phase ini, build lama harus berubah menjadi **awal playable forward 3D flight**. Phase ini tidak boleh berhenti hanya di skeleton kosong; harus sampai terlihat di browser: pesawat GLB dari kamera belakang-sedikit-atas, bergerak maju dalam corridor.

### Scope Phase 1

#### 1.1 Scene foundation

- [x] Buat `scripts/forward_air_scene_3d.gd`.
- [x] Tambah `ForwardAirScene3D` sebagai child runtime dari current main shell.
- [x] Tambah `WorldEnvironment`, fog/sky storm color, `DirectionalLight3D`.
- [x] Tambah `CameraRig3D` + `Camera3D`.
- [x] Set world convention: forward = `-Z`.
- [x] Tambah bridge state:
  - `missionMode: forward_air_combat`
  - `cameraMode: chase_behind_above`
  - `playerModel: glb`

#### 1.2 Player GLB placeholder/final first pass

- [x] Buat/import `assets/models/player_stormhawk.glb`.
- [x] Kalau final asset belum siap, buat procedural GLB placeholder yang tetap 3D nyata.
- [x] Model minimal harus punya fuselage, wings, cockpit, tail, engine sockets, hardpoint sockets.
- [x] Material awal: dark metal, cyan emissive strips, canopy glass.
- [x] Tambah `PlayerRig3D` dan pasang model ke scene.

#### 1.3 Chase camera feel

- [x] Kamera berada di belakang dan sedikit di atas player.
- [x] Kamera melihat ke depan jalur, bukan ke bawah/top-down.
- [x] Player berada lower third layar 9:16.
- [x] Tambah camera lag halus.
- [x] Tambah roll influence ringan saat player strafe.
- [x] Tambah FOV kick placeholder untuk boost.

#### 1.4 Forward flight controls

- [x] Konversi input ke corridor 3D:
  - X = strafe kiri/kanan;
  - Y = altitude/dodge naik-turun;
  - forward motion = world/chunks bergerak terhadap player atau player bergerak `-Z`.
- [x] Touch drag mengontrol X/Y corridor.
- [x] Keyboard WASD/arrow tetap bisa testing.
- [x] Clamp corridor supaya mobile readable.
- [x] Tambah roll/pitch visual pada player model.

#### 1.5 Minimal forward motion proof

- [x] Tambah beberapa debug corridor markers/air lane rings di depan.
- [x] Tambah placeholder cloud/terrain/debris simple 3D yang bergerak dari depan ke belakang untuk membuktikan maju.
- [x] Matikan top-down gameplay renderer saat mission forward aktif.
- [x] Pastikan tidak ada car/convoy UI di flow launch.

#### 1.6 Browser proof

- [x] Godot check/import.
- [x] Export Web root.
- [x] `npm run vercel-build`.
- [x] `npm run qa:web`.
- [ ] Restart preview. (done after server restart, if requested in current run)
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

- [x] Browser menunjukkan `ForwardAirScene3D`.
- [x] Player aircraft adalah GLB/model 3D, bukan PNG.
- [x] Kamera jelas dari belakang sedikit di atas.
- [x] Pesawat bisa digerakkan kiri/kanan/naik/turun dalam corridor.
- [x] Ada bukti gerak maju ke depan dalam depth.
- [x] Tidak ada car/convoy prologue.
- [x] Tidak ada top-down player sprite sebagai gameplay utama.
- [x] Root Web export dan browser QA pass.

### Progress setelah Phase 1 selesai

Phase 1 lolos acceptance gate. Progress forward rebuild sekarang **±35%**. Build ini masih belum final combat; Phase 2 harus membuat arena sinematik/weather battlefield.

---

## 6. Phase 2 — Cinematic Arena & Weather Battlefield

**Status:** Done for first cinematic/weather battlefield pass
**Tujuan besar:** mengubah forward scene Phase 1 dari corridor kosong menjadi **arena perang badai 3D hidup** sesuai visual lock.

### Scope Phase 2

#### 2.1 Forward arena director

- [x] Buat `scripts/forward_arena_director.gd`.
- [x] Buat system chunk spawn/despawn di depan kamera.
- [x] Rework `air_cloud_cluster.glb` atau buat cloud bank GLB baru.
- [x] Rework `air_arena_tile.glb` menjadi arena forward chunks, bukan tile top-down.
- [x] Tambah ocean/city warzone layer di bawah jalur terbang.

#### 2.2 Layered battlefield depth

- [x] Far storm sky layer bergerak lambat.
- [x] Mid cloud banks bergerak medium.
- [x] Near debris/smoke streak bergerak cepat.
- [x] Warzone below bergerak perspektif.
- [x] Distant air traffic: ally/enemy silhouettes, tracer lines, tiny explosions.

#### 2.3 Weather as gameplay volume

- [x] Wind field mempengaruhi smoke/trails dan sedikit steering/turbulence.
- [x] Cloud volume menyembunyikan musuh/target marker sampai dekat atau radar aktif.
- [x] Rain sheets menurunkan visibility.
- [x] Lightning flash menerangi arena dan men-trigger overcharge placeholder.
- [x] Storm cell hazard memaksa lane/altitude choice.

#### 2.4 Cinematic quality pass

- [x] Color grading storm/sunset blue-orange.
- [x] Light flashes and cloud edge lighting.
- [x] Smoke columns dari warzone bawah.
- [x] Fire pockets/explosions ambient.
- [x] Speed tuning supaya terasa maju tapi tidak terlalu cepat.

### Deliverable Phase 2

Build browser yang memperlihatkan:

```text
3D forward flight through storm battlefield
cloud depth + warzone below + smoke/fire + debris
weather starts affecting movement/visibility/VFX
arena no longer feels empty or flat
```

### Acceptance Gate Phase 2

- [x] Minimal 4 depth layers terlihat jelas.
- [x] Arena bukan static photo dan bukan flat tile scroll.
- [x] Weather punya efek gameplay awal, bukan overlay dekoratif.
- [x] Kecepatan forward readable dan tidak terlalu cepat.
- [x] Browser QA pass.

### Progress setelah Phase 2 selesai

Phase 2 lolos acceptance gate. Forward rebuild sekarang **±52–55%**. Build masih belum full combat; Phase 3 harus menambahkan weapon/enemy/boss package.

---

## 7. Phase 3 — Weapon, Enemy, Boss Combat Package

**Status:** Active Next
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
- [x] `npm run vercel-build`.
- [x] `npm run qa:web`.
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

Phase 2 selesai untuk first cinematic/weather battlefield pass. Next work adalah:

```text
Phase 3 — Weapon, Enemy, Boss Combat Package
```

Urutan kerja Phase 3:

1. Buat `weapon_vfx_director.gd` untuk hardpoint fire dari GLB aircraft.
2. Buat `enemy_director_3d.gd` untuk enemy fighter/drone/gunship di depth depan.
3. Tambah projectile readable; enemy bullets tidak boleh terus-menerus chasing player.
4. Tambah hit sparks, smoke trails, and debris impacts.
5. Tambah first boss/dreadnought shell sebagai anchor besar di depan.
6. Integrasikan wind/cloud/lightning ke bullet/VFX behavior.
7. Export Web + browser QA.

Phase 3 tidak selesai sampai combat 3D benar-benar terlihat dari chase camera.

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


```text
Phase: Phase 1 — Core Forward Flight Rebuild
Status: Done for first playable forward-flight core
Changed files: scripts/forward_air_scene_3d.gd, scripts/main.gd, assets/models/player_stormhawk.glb, qa/forward-flight-browser-qa.mjs, root Web export
Validation run: Godot check/import, forward smoke, export_web, npm run vercel-build, npm run qa:web, npm run qa:forward
Visible result in browser: missionMode=forward_air_combat, cameraMode=chase_behind_above, playerModel=glb, canvas=720x1280
What remains incomplete: cinematic arena, hardpoint weapons, enemy waves, boss dreadnought, legacy physical cleanup
Next work: Phase 2 — Cinematic Arena & Weather Battlefield
```


```text
Phase: Phase 2 — Cinematic Arena & Weather Battlefield
Status: Done for first cinematic/weather battlefield pass
Changed files: scripts/forward_arena_director.gd, scripts/forward_air_scene_3d.gd, scripts/main.gd, qa/forward-flight-browser-qa.mjs, docs/PHASE_2_CINEMATIC_ARENA_WEATHER_REPORT.md, root Web export
Validation run: Godot check/import, Phase2 smoke, export_web, npm run vercel-build, npm run qa:web, npm run qa:forward
Visible result in browser: arenaPhase=storm_battlefield, depthLayerCount=5, weatherGameplay=true, wind/rain/cloud/hazard bridge values active
What remains incomplete: hardpoint weapons, enemy waves, boss dreadnought, final balancing, legacy physical cleanup
Next work: Phase 3 — Weapon, Enemy, Boss Combat Package
```
