# Phase 1 Completion Report — Core Forward Flight Rebuild

Tanggal: 2026-10-05
Branch: `arena/01a100ae-force-war`
Phase: **Phase 1 — Core Forward Flight Rebuild**
Status: **Done for first playable forward-flight core**

Phase 1 mengubah arah gameplay dari baseline top-down lama menjadi bukti playable awal untuk **3D forward air-combat**. Hasil phase ini sudah memenuhi gate utama: player aircraft memakai GLB 3D, kamera chase berada di belakang-sedikit-atas, game bergerak maju dalam depth 3D, dan Web/browser QA bisa masuk sampai mission mode baru.

---

## 1. What Changed

### New runtime scene

```text
scripts/forward_air_scene_3d.gd
```

Scene ini dibuat sebagai child runtime dari shell utama saat mission dimulai. Ia menangani:

- `ForwardAirScene3D` root;
- `WorldEnvironment` storm color/fog;
- `DirectionalLight3D`;
- `Camera3D` chase behind/above;
- `PlayerRig3D`;
- forward depth lane markers;
- placeholder clouds/warzone chunks/debris;
- corridor movement and camera lag;
- bridge state for browser QA.

### New player GLB

```text
assets/models/player_stormhawk.glb
assets/models/player_stormhawk.glb.import
```

GLB ini adalah placeholder 3D nyata, bukan PNG/photo. Model memuat:

- fuselage;
- swept wings;
- cockpit canopy;
- tail/engine housings;
- cyan emissive strips;
- hardpoint/socket markers;
- engine cores.

### Main integration

`scripts/main.gd` sekarang:

- mem-preload `forward_air_scene_3d.gd`;
- membuat `forward_scene` runtime;
- pada direct mission launch memulai `ForwardAirScene3D`, bukan `setup_air_arena_scene()` lama;
- mengirim bridge state:
  - `missionMode: forward_air_combat`
  - `cameraMode: chase_behind_above`
  - `playerModel: glb`
- mengupdate forward scene selama `GameState.PLAYING`;
- menggambar HUD forward-flight khusus dan tidak lagi menggambar top-down gameplay world saat forward scene aktif.

### New forward browser QA

```text
qa/forward-flight-browser-qa.mjs
npm run qa:forward
```

QA ini membuka root Web export, men-skip loading, masuk briefing, launch mission, lalu memverifikasi browser bridge:

- canvas 720x1280;
- `missionMode === "forward_air_combat"`;
- `cameraMode === "chase_behind_above"`;
- `playerModel === "glb"`;
- forward scene active.

---

## 2. Phase 1 Acceptance Gate

| Gate item | Result |
| --- | --- |
| Browser shows `ForwardAirScene3D` state | Passed via `npm run qa:forward` |
| Player aircraft is GLB/model 3D | Passed via `playerModel: glb` and `player_stormhawk.glb` runtime load |
| Camera is behind/slightly above | Passed via `cameraMode: chase_behind_above` and `ChaseCamera_BehindAbove` |
| Aircraft can move in 3D corridor | Implemented with keyboard/touch X/Y corridor movement |
| Forward depth readable | Implemented with lane gates, cloud chunks, warzone chunks, debris motion |
| No car/convoy prologue visible in launch flow | Passed; direct launch starts forward air scene |
| No top-down player sprite as gameplay main mode | Passed while forward scene is active |
| Root Web export updated | Passed |
| Browser QA passed | Passed |

---

## 3. Validation Run

```text
Godot --check-only scripts/main.gd                 -> passed
Godot --check-only scripts/forward_air_scene_3d.gd -> passed
Godot --import --quit                              -> passed
Forward smoke                                      -> passed
./tools/export_web.sh                              -> passed
npm run vercel-build                               -> passed
npm run qa:web                                     -> passed
npm run qa:forward                                 -> passed
```

Forward browser QA result:

```text
Forward browser QA ok: mode=forward_air_combat camera=chase_behind_above model=glb progress=0.004 canvas=720x1280
```

Root Web export result after Phase 1:

```text
index.html 5638
index.js 315759
index.wasm 37695054
index.pck 12411264
```

---

## 4. Honest Limitations After Phase 1

Phase 1 is **not** the final combat game yet. It is the first visible forward-flight core.

Still missing:

- no full cinematic battlefield yet;
- arena is still placeholder lane/cloud/warzone proof, not final target-quality environment;
- no 3D weapon hardpoint firing yet;
- no enemy GLB waves yet;
- no boss dreadnought yet;
- old car/convoy/top-down code still exists in repository but is inactive during forward scene launch;
- old PNG gameplay assets still exist until Phase 4 cleanup.

---

## 5. Progress Update

Phase 1 completion allows the forward rebuild estimate to move from ±10% to:

```text
Forward 3D gameplay rebuild: ±35%
Full product including Web pipeline/docs: ±38–40%
```

This is still not full game completion. It only means the new camera/player/movement foundation is now playable in browser.

---

## 6. Next Phase

Next phase:

```text
Phase 2 — Cinematic Arena & Weather Battlefield
```

Phase 2 should not be small tweaking. It should build the real battlefield feel:

1. `ForwardArenaDirector` script.
2. Storm cloud banks in depth.
3. Ocean/city warzone below flight path.
4. Smoke columns, fire pockets, distant explosions.
5. Wind/rain/cloud/lightning as 3D gameplay volumes.
6. Speed/camera comfort tuning.
7. Browser QA proving the arena no longer feels empty or flat.
