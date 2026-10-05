# Force War — Rebuild Roadmap & Progress Milestones

Tanggal: 2026-10-05
Branch kerja: `arena/01a100ae-force-war`

Dokumen ini adalah **roadmap rebuild** untuk mengubah Force War dari baseline lama menjadi **3D forward air-combat**: pesawat GLB 3D, kamera chase dari belakang-sedikit-atas, gerak maju ke depan, arena badai 3D, dan VFX sinematik sesuai `gameplay_visual_lock_build.jpg`.

> Status jujur: rebuild gameplay belum dimulai. Yang sudah selesai adalah design lock, audit repo lama, dan pembersihan dokumen/tool lama. Build Web lama masih ada sebagai baseline teknis sampai scene 3D baru siap menggantikan.

---

## 1. Target Rebuild yang Tidak Boleh Berubah

Non-negotiable untuk semua milestone:

1. **Player aircraft = GLB 3D**, bukan PNG/foto/static sprite.
2. **Camera = chase camera**, di belakang pesawat dan sedikit di atas.
3. **Movement = maju ke depan dalam depth 3D**, bukan scroll ke atas.
4. **Arena = 3D layered storm battlefield**, bukan static photo/parallax 2D.
5. **VFX keluar dari hardpoint model**, bukan garis canvas yang terasa lepas dari pesawat.
6. **Tidak ada car/convoy prologue** dalam player-facing flow.
7. **Tidak ada top-down gameplay** sebagai mode utama.
8. **Web export tetap root repo**: `index.html`, `index.js`, `index.wasm`, `index.pck`.

---

## 2. Status Progress Saat Ini

| Area | Status | Progress realistis | Catatan |
| --- | --- | ---: | --- |
| Design lock forward 3D | Done | 100% | `THIRD_PERSON_AIR_COMBAT_REDESIGN.md` sudah dibuat. |
| Visual reference lock | Done | 100% | `gameplay_visual_lock_build.jpg` menjadi mood/quality target. |
| Repo audit setup lama | Done for docs | 80% | Code/assets legacy masih ada, tapi sudah dipetakan. |
| Web pipeline | Stable baseline | 80% | `npm start`, Vercel headers, root export masih aktif. |
| ForwardAirScene3D gameplay | Not started | 0% | R2 belum dimulai; R1 cut points sudah dipetakan. |
| Player GLB final | Not started | 0% | Belum ada `player_stormhawk.glb`. |
| Chase camera rig | Not started | 0% | Belum implement. |
| Forward arena director | Not started | 0% | GLB tile/cloud lama belum dirombak. |
| 3D weapon VFX | Not started | 0% | Efek lama masih 2D/procedural baseline. |
| Boss dreadnought GLB | Not started | 0% | Baru target desain. |
| Legacy code removal | Mapped | 10% | Keep/rewrite/delete map selesai; removal fisik ditunda sampai replacement 3D playable. |

### Estimasi overall rebuild

```text
Forward 3D gameplay rebuild only: ±10%
Full product including existing Web pipeline/docs: ±26%
```

Angka ini sengaja konservatif. Jangan menaikkan progress hanya karena dokumen selesai; milestone gameplay harus dibuktikan lewat browser preview.

---

## 3. Milestone Board

| ID | Milestone | Status | Target output utama | Gate |
| --- | --- | --- | --- | --- |
| R0 | Direction Lock & Cleanup Docs | Done | Docs baru + audit setup lama | Gate 0 |
| R1 | Rebuild Prep & Legacy Quarantine | Done | Code map, deletion plan, scene split plan | Gate 1 |
| R2 | ForwardAirScene3D Skeleton | Next | Scene 3D baru bootable | Gate 2 |
| R3 | Player GLB + Chase Camera | Planned | Pesawat GLB terlihat dari kamera belakang | Gate 3 |
| R4 | 3D Flight Corridor Controls | Planned | Movement maju/strafe/altitude/roll | Gate 4 |
| R5 | Forward Arena Director | Planned | Arena 3D bergerak maju berlapis | Gate 5 |
| R6 | 3D Weapon VFX Director | Planned | Tembakan kuat dari hardpoint GLB | Gate 6 |
| R7 | Enemy Waves + Boss Set Piece | Planned | Musuh GLB + boss dreadnought 3D | Gate 7 |
| R8 | Weather Gameplay Integration | Planned | Wind/cloud/rain/lightning berfungsi di 3D | Gate 8 |
| R9 | HUD/UI Refit | Planned | Reticle, lock-on, boss bar, ability buttons | Gate 9 |
| R10 | Legacy Removal & Repo Slimming | Planned | Car/convoy/top-down code/assets dibersihkan | Gate 10 |
| R11 | Web Export + Browser QA | Planned | Root export baru + QA visual 3D | Gate 11 |
| R12 | Content Expansion Pass | Later | Multiple aircraft/enemy/boss/stage | Gate 12 |

---

## 4. Detailed Rebuild Roadmap

### R0 — Direction Lock & Cleanup Docs

**Status:** Done
**Commit reference:** `f00934f Lock forward 3D air combat redesign`

Deliverables:

- [x] Visual lock `gameplay_visual_lock_build.jpg` recognized as target reference.
- [x] `docs/THIRD_PERSON_AIR_COMBAT_REDESIGN.md` created.
- [x] `docs/REPO_CLEANUP_AUDIT.md` created.
- [x] README rewritten to forward 3D direction.
- [x] Roadmap, asset catalog, FX, UI/UX, Web flow docs rewritten.
- [x] Old helper/generator tools removed from repo.

Exit criteria:

- Docs no longer present old top-down/convoy/car as active direction.
- Old setup is marked legacy/quarantine.

---

### R1 — Rebuild Prep & Legacy Quarantine

**Status:** Done
**Goal:** siapkan pembedahan code tanpa merusak Web baseline sebelum replacement scene siap.

Tasks:

- [x] Map all `scripts/main.gd` sections into categories:
  - keep: Web bridge, save shell, loading shell, shared UI utilities;
  - rewrite: gameplay update loop, camera, player control, weapon system;
  - delete later: car/convoy/ground chase/top-down rendering.
- [x] Define new script/module layout:
  - `ForwardAirScene3D` / `ForwardArenaDirector` / `WeaponVFXDirector` / `EnemyDirector3D`.
- [x] Decide whether to keep one-file prototype first or split scripts immediately.
- [x] Create strict forbidden-runtime list:
  - `ground_car`, `convoy`, top-down player draw, static gameplay background.
- [x] Create QA checklist for visual 3D verification.

Deliverables:

- [x] New `docs/CODE_REBUILD_MAP.md` added.
- [x] No gameplay behavior changed.

Exit criteria:

- [x] Next coding pass has exact cut points and no accidental old-system carryover.

---

### R2 — ForwardAirScene3D Skeleton

**Status:** Planned

Goal: create a minimal 3D gameplay scene that can boot in browser.

Tasks:

- [ ] Create/add `ForwardAirScene3D` root under current main scene or replace gameplay child.
- [ ] Add `WorldEnvironment`, `DirectionalLight3D`, storm sky clear color/fog.
- [ ] Add `CameraRig3D` and placeholder `PlayerRig3D`.
- [ ] Add forward direction convention: `-Z`.
- [ ] Add debug markers showing corridor bounds in 3D.
- [ ] Add bridge state `missionMode: forward_air_combat`.

Deliverables:

- Browser can display a 3D scene, even before final aircraft GLB.

Exit criteria:

- 720x1280 canvas loads.
- Godot scene contains active Camera3D for gameplay.
- No top-down gameplay rendering is visible in this mode.

---

### R3 — Player GLB + Chase Camera

**Status:** Planned

Goal: replace player sprite/photo logic with actual aircraft GLB and camera behind/slightly above.

Tasks:

- [ ] Create/import `assets/models/player_stormhawk.glb` placeholder if final model not ready.
- [ ] Add material identity: dark metal, cyan emissive, cockpit glass.
- [ ] Add hardpoint sockets or known child transforms.
- [ ] Add engine sockets.
- [ ] Add chase camera position:
  - camera behind player;
  - slightly above;
  - looking ahead along `-Z`.
- [ ] Add camera lag and basic roll follow.

Deliverables:

- Player GLB visible in lower third of portrait screen.
- Camera perspective clearly reads behind/above.

Exit criteria:

- Screenshot proves player is 3D GLB, not PNG.
- Camera is not top-down.
- Plane nose points toward forward depth.

---

### R4 — 3D Flight Corridor Controls

**Status:** Planned

Goal: player controls aircraft within forward corridor.

Tasks:

- [ ] Convert movement to local 3D corridor:
  - X = left/right strafe;
  - Y = altitude/vertical dodge;
  - Z = forward illusion/path.
- [ ] Add roll/tilt animation based on X input.
- [ ] Add pitch response for Y input.
- [ ] Add boost/brake/FOV kick prototype.
- [ ] Map touch drag to X/Y corridor movement.
- [ ] Add clamp/bounds and visual corridor feedback.

Deliverables:

- Player can dodge in a 3D forward corridor.

Exit criteria:

- Movement no longer feels like 2D top-down plane icon movement.
- Touch/mobile control still playable.

---

### R5 — Forward Arena Director

**Status:** Planned

Goal: build animated 3D arena that moves forward into storm warzone.

Tasks:

- [ ] Rework or replace `air_arena_tile.glb` into forward chunks.
- [ ] Reuse or replace `air_cloud_cluster.glb` as cloud banks in depth.
- [ ] Add ocean/city warzone layer below flight path.
- [ ] Add smoke columns, fire pockets, distant explosions.
- [ ] Add near/mid/far parallax movement in 3D.
- [ ] Add debris/air traffic silhouettes for depth.

Deliverables:

- Arena reads as forward flight through battlefield.

Exit criteria:

- 4+ depth layers visible.
- Nothing feels like static photo or flat vertical scroll.
- Speed is cinematic and controllable, not too fast.

---

### R6 — 3D Weapon VFX Director

**Status:** Planned

Goal: make player shots visually strong and attached to aircraft hardpoints.

Tasks:

- [ ] Main cannon: cyan/white stream from nose/inner hardpoints.
- [ ] Wing cannon: thicker bolts from wings.
- [ ] Micro missiles: physical projectile + smoke trail.
- [ ] Overcharge laser: blue-white beam + arcs + impact flare.
- [ ] Engine exhaust: always visible flame/vapor.
- [ ] Hit sparks/debris/smoke on impact.
- [ ] Camera coupling: shake/FOV for heavy weapons.

Deliverables:

- Weapon effects no longer look like only 2 weak bullets.

Exit criteria:

- A paused screenshot shows strong multi-source fire.
- Shots originate from GLB hardpoints.
- Player fire is clearly blue/cyan and enemy fire red/orange.

---

### R7 — Enemy Waves + Boss Set Piece

**Status:** Planned

Goal: create real 3D enemy/boss combat in front of player.

Tasks:

- [ ] Add enemy drone/fighter GLB placeholders.
- [ ] Spawn enemies ahead in 3D lanes.
- [ ] Add readable red/orange projectile patterns.
- [ ] Add target brackets/lock-on markers.
- [ ] Add boss dreadnought GLB placeholder.
- [ ] Add boss weakpoints and turret hardpoints.
- [ ] Add central cannon charge/laser telegraph.

Deliverables:

- First boss assault scene resembles target visual direction.

Exit criteria:

- Boss is a 3D object in depth, not a static top image.
- Enemy fire is readable and not constant unfair homing.

---

### R8 — Weather Gameplay Integration

**Status:** Planned

Goal: port weather puzzle system into forward 3D gameplay.

Tasks:

- [ ] Wind bends smoke/trails/projectiles and adds turbulence.
- [ ] Clouds hide enemies until close or radar active.
- [ ] Rain reduces visibility with camera/world streaks.
- [ ] Lightning overcharges weapons and strikes targets/rods.
- [ ] Storm cells act as moving corridor hazards.
- [ ] Briefing forecast affects recommended loadout.

Deliverables:

- Weather changes gameplay, not just background color.

Exit criteria:

- Player can identify and react to at least 3 weather hazards in 3D.

---

### R9 — HUD/UI Refit

**Status:** Planned

Goal: adapt UI to chase-camera combat.

Tasks:

- [ ] Center reticle/crosshair.
- [ ] Lock-on ring and target brackets.
- [ ] Boss bar top-center.
- [ ] HP/shield top-left.
- [ ] Score/combo top-right.
- [ ] Ability buttons lower safe zones.
- [ ] Radar/weather mini-map bottom-right.
- [ ] Remove car/garage/convoy UI text.

Deliverables:

- Mobile 9:16 HUD supports forward flight readability.

Exit criteria:

- UI does not hide player aircraft or dodge zone.
- No old car/convoy UI appears.

---

### R10 — Legacy Removal & Repo Slimming

**Status:** Planned after R2–R9 are playable

Goal: remove old setup safely after replacement exists.

Tasks:

- [ ] Remove ground car phase code.
- [ ] Remove convoy code and events.
- [ ] Remove top-down aircraft draw as runtime mode.
- [ ] Remove deprecated car/convoy assets after grep confirms no references.
- [ ] Remove gameplay dependency on `assets/rendered/player_stormhawk.png`.
- [ ] Replace old save key with migration strategy.
- [ ] Clean docs again to remove old references outside audit/changelog.

Deliverables:

- Repo no longer contains old active gameplay paths.

Exit criteria:

- Grep forbidden strings only finds audit/changelog/reference docs.
- Web export still works.

---

### R11 — Web Export + Browser QA

**Status:** Planned

Goal: validate rebuilt game in browser.

Tasks:

- [ ] Godot `--check-only` script validation.
- [ ] Godot import.
- [ ] `./tools/export_web.sh`.
- [ ] `npm run vercel-build`.
- [ ] `npm run qa:web`.
- [ ] Add visual QA check for:
  - active Camera3D;
  - GLB player visible;
  - `missionMode: forward_air_combat`;
  - no car/convoy UI.
- [ ] Restart preview.

Deliverables:

- Browser preview shows rebuilt 3D forward air combat.

Exit criteria:

- QA passes and user can visually inspect live preview.

---

### R12 — Content Expansion Pass

**Status:** Later

Goal: expand after first forward slice is accepted.

Tasks:

- [ ] 4 player aircraft GLB variants.
- [ ] 6+ enemy GLB types.
- [ ] 3 boss dreadnought variants.
- [ ] 3+ arena biomes.
- [ ] Upgrade/economy tuning.
- [ ] Audio pass.
- [ ] Loading/menu art regenerated to match aircraft-only direction.
- [ ] Save/progression polish.

Deliverables:

- Production vertical slice moving toward full version.

---

## 5. Gate Definitions

### Gate 0 — Direction Gate

Passed if design direction is clear and no old direction is treated as target.

Current status: **Passed**.

### Gate 1 — Prep Gate

Passed if code map and cleanup plan are precise enough to avoid accidental old-system carryover.

Current status: **Next**.

### Gate 2 — Scene Gate

Passed if browser shows a 3D scene with active chase-camera infrastructure.

### Gate 3 — Aircraft Gate

Passed if player aircraft is a GLB visible from behind/slightly above.

### Gate 4 — Control Gate

Passed if movement reads as flight within a forward corridor.

### Gate 5 — Arena Gate

Passed if arena has layered forward motion and storm battlefield depth.

### Gate 6 — Weapon Gate

Passed if player fire is strong, hardpoint-based, and visually clear.

### Gate 7 — Combat Gate

Passed if enemies/boss exist in 3D and attack patterns are readable.

### Gate 8 — Weather Gate

Passed if weather affects moment-to-moment decisions.

### Gate 9 — UI Gate

Passed if HUD supports forward flight and no old UI remains.

### Gate 10 — Cleanup Gate

Passed if old gameplay code/assets are no longer active.

### Gate 11 — Web Gate

Passed if root export + browser QA pass with the rebuilt 3D scene.

---

## 6. Immediate Next Work Order

R1 is complete. Next work should be **R2 only**, not random VFX/gameplay tweaking:

1. Create `scripts/forward_air_scene_3d.gd`.
2. Instantiate a minimal `ForwardAirScene3D` from the current main shell.
3. Add WorldEnvironment, DirectionalLight3D, CameraRig3D, and placeholder PlayerRig3D.
4. Report bridge state `missionMode: forward_air_combat` and `cameraMode: chase_behind_above`.
5. Keep loading/title/briefing shell intact until the 3D gameplay scene is visible.

---

## 7. Progress Update Template

Use this template after every rebuild commit:

```text
Milestone: R# — Name
Status: Not started / In progress / Blocked / Done
Changed files:
Validation run:
What is visibly different:
What remains incomplete:
Next step:
```

---

## 8. Do Not Claim Done Until

Do not mark forward rebuild as playable until all are true:

- player GLB visible;
- chase camera visible in browser;
- forward movement readable;
- arena has 3D depth;
- weapon VFX emitted from model hardpoints;
- old car/convoy/top-down flow absent;
- root Web export rebuilt and QA passed.

## 9. Progress Log

```text
Milestone: R1 — Rebuild Prep & Legacy Quarantine
Status: Done
Changed files: docs/CODE_REBUILD_MAP.md, docs/REBUILD_ROADMAP_AND_MILESTONES.md, docs/ROADMAP.md, README.md, docs/REPO_CLEANUP_AUDIT.md
Validation run: git diff --check; npm run vercel-build
What is visibly different: no gameplay visual change; this phase is prep only
What remains incomplete: ForwardAirScene3D skeleton is not created yet
Next step: R2 — create minimal 3D forward air scene and chase camera skeleton
```
