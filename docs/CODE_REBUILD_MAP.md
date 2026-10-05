# Force War — Code Rebuild Map (Phase 1 Prep)

Tanggal: 2026-10-05
Milestone: **Phase 1 Prep — Core Forward Flight Rebuild Preparation**

Dokumen ini memetakan `scripts/main.gd` dan scene/project setup saat ini sebelum masuk implementation Phase 1. Tujuannya supaya rebuild tidak membawa kembali sistem lama: top-down, convoy/car, static PNG gameplay, dan upward scroll.

> Pass ini adalah prep/analysis. Tidak ada gameplay behavior yang diubah di prep phase ini.

---

## 1. Current Baseline Snapshot

| Item | Current state | Rebuild implication |
| --- | --- | --- |
| Main scene | `scenes/Main.tscn` root masih `Node2D` dengan script `scripts/main.gd` | Phase 1 boleh sementara menambah `Node3D` child untuk scene forward, lalu Phase 4 bisa migrasi ke root `Node` + `CanvasLayer`. |
| Main script | `scripts/main.gd`, 3521 lines, `extends Node2D` | Terlalu besar dan campur: loading, UI, save, top-down gameplay, convoy, ground car, 3D arena lama. Perlu split bertahap. |
| GameState | `LOADING, TITLE, BRIEFING, HANGAR, GROUND, PLAYING, STAGE_CLEAR, GAME_OVER, PAUSED` | `GROUND` harus dihapus nanti. `PLAYING` menjadi forward air combat. |
| Save key | `force-war-storm-convoy-v2` | Harus migrasi ke `force-war-forward-air-v1` setelah gameplay baru stabil. |
| Player | Dictionary 2D `player` + PNG draw | Diganti `ForwardPlayerRig3D` + GLB. |
| Camera | 2D canvas draw + old 3D arena camera/background | Diganti chase camera behind/slightly above. |
| Assets | Gameplay masih load PNG player/enemy/convoy/background | Gameplay baru hanya GLB/3D/particles; PNG tinggal logo/loading/UI. |

---

## 2. New Runtime Architecture Target

### 2.1 Short-term Phase 1 architecture

Untuk mengurangi risiko besar, Phase 1 boleh tetap memakai `Main.tscn` saat ini sebagai host shell, tetapi gameplay world baru dibuat sebagai child 3D:

```text
Main (Node2D, scripts/main.gd, temporary shell)
  ForwardAirScene3D (Node3D, scripts/forward_air_scene_3d.gd)
    WorldEnvironment
    DirectionalLight3D
    CameraRig3D
      Camera3D
    PlayerRig3D
      PlayerAircraftGLB
      Hardpoint nodes
    ForwardArenaDirector
    EnemyDirector3D
    WeaponVFXDirector
  Canvas/UI draw from Main temporarily
```

Alasan:

- loading/title/briefing/Web bridge tidak langsung rusak;
- root export dan QA lebih aman;
- gameplay lama bisa dimatikan state-by-state tanpa big-bang rewrite.

### 2.2 Long-term clean architecture

Setelah Phase 4 cleanup:

```text
Main (Node)
  ForwardAirScene3D (Node3D)
  HUDCanvasLayer (CanvasLayer)
  MenuCanvasLayer (CanvasLayer)
```

`main.gd` menjadi orchestrator tipis, bukan tempat semua gameplay.

---

## 3. New Script Layout Decision

Phase 1 prep decision: **split new forward systems into new scripts**, while `main.gd` stays as temporary app shell.

Planned scripts:

| Script | Owner | Purpose |
| --- | --- | --- |
| `scripts/forward_air_scene_3d.gd` | Node3D | Owns forward mission scene, camera rig, player rig, high-level update. |
| `scripts/forward_player_rig.gd` | Node3D | Player aircraft GLB, movement, roll/pitch, health/shield sockets. |
| `scripts/forward_arena_director.gd` | Node3D | Clouds, ocean/city chunks, smoke columns, battlefield depth. |
| `scripts/weapon_vfx_director.gd` | Node3D | Hardpoint weapon emission, trails, missiles, laser, impact FX. |
| `scripts/enemy_director_3d.gd` | Node3D | Enemy waves, boss dreadnought, attack patterns. |
| `scripts/forward_hud.gd` | CanvasLayer later | Reticle, lock-on, boss bar, ability buttons. |

Phase 1 implementation may start with only `forward_air_scene_3d.gd` to prove camera/GLB visibility. Other scripts can be added as systems become real.

---

## 4. Function Map: Keep / Rewrite / Delete Later

Line numbers are from the current `scripts/main.gd` at Phase 1 prep start.

### 4.1 Keep with light edits

These are useful shell/system utilities and should survive the first forward rebuild pass.

| Lines | Function/section | Keep reason | Required edit later |
| --- | --- | --- | --- |
| 146–168 | `_ready()` | Initializes RNG, save, textures, loading, JS ready | Add forward scene bootstrap after loading or stage start. |
| 169–192 | `_process(delta)` | State update hub | Route `PLAYING` to `ForwardAirScene3D` instead of old 2D update. |
| 193–251 | `_input(event)` | Shared input/touch/menu handling | Redirect gameplay input to forward player controls. |
| 344–367 | loading helpers | Mobile loading flow still needed | Replace loading backgrounds if convoy/car art appears. |
| 409–497 | `make_stage_defs()` | Mission/weather data useful | Rename wording from route/vertical to air corridor when implementing. |
| 498–530 | `make_loadouts()` | Forecast/loadout concept still valid | Reframe support tools for aircraft-only. |
| 531–539 | `make_aircraft_defs()` | Aircraft progression still valid | Extend for GLB model path/hardpoint data. |
| 549–650 | save utility functions | Save/localStorage structure useful | Remove car arrays; migrate key. |
| 660–668 | aircraft index/data | Keep for aircraft-only | Add GLB path and forward stats. |
| 714–779 | upgrade labels/costs/aircraft stats | Keep subset | Remove car branch and car upgrade keys. |
| 890–948 | menu tap rects/handler | Keep menu shell | Remove car/garage tab routing. |
| 1095–1106 | `spawn_weather_field()` | Weather system concept useful | Convert cloud/hazard data to 3D volumes. |
| 1155–1174 | `instantiate_air_model()` | Useful GLB load helper | Rename/generalize for forward scene or move to new script. |
| 2349–2391 | weather/lightning core | Weather gameplay useful | Rewrite strike targets and VFX in 3D. |
| 2490–2499 | `damage_player()` | Health/damage concept useful | Move into forward player rig or facade. |
| 2521–2557 | stage clear/game over | Useful game loop shell | Update rewards/objectives for forward combat. |
| 2558–2566 | `weather_value`, `current_wind` | Weather lookup useful | Keep as shared mission data. |
| 2619–2629 | `nearest_enemy()` | Concept useful | Rewrite for 3D enemy director. |
| 2630–2645 | smoke/cloud visibility checks | Concept useful | Convert to 3D distance/volume checks. |
| 2650–2676 | warning/particles helpers | UI/VFX utility useful | Split particles into 2D UI vs 3D VFX. |
| 2694–2746 | JS bridge/state helpers | Web integration required | Rename state fields to forward-air terms. |
| 3159–3266 | loading/title/briefing draw | Shell useful | Replace art/wording if needed. |
| 3482–3512 | panel/bar/text draw utilities | Useful for UI shell | Later move to CanvasLayer/HUD script. |

### 4.2 Rewrite completely

These functions may keep names temporarily, but their internals must become forward 3D logic.

| Lines | Function/section | Why rewrite |
| --- | --- | --- |
| 368–408 | `load_textures()` | Currently loads gameplay PNG player/enemy/convoy/background. New gameplay must load GLB/particles; PNG only UI/loading. |
| 608–626 | `ensure_save_shape()` | Contains car arrays and selected car. Needs aircraft-only schema. |
| 797–838 | `purchase_or_upgrade_selected()` | Mixed aircraft/car logic. Needs aircraft-only upgrade categories. |
| 839–889 | hangar selection/key handling | Currently has aircraft/car abstraction. Needs aircraft-only hangar. |
| 982–996 | `reset_player()` | Creates 2D player dict. Needs forward player rig reset/start. |
| 997–1079 | `start_stage()` | Currently initializes 2D route/convoy/enemies and air arena. Needs forward mission bootstrap. |
| 1175–1226 | `setup_air_arena_scene()` | Old background 3D arena, not chase gameplay. Rebuild as `ForwardAirScene3D`. |
| 1227–1267 | `update_air_arena_3d()` | Old world-background scroll. Needs forward chunk director. |
| 1655–1690 | `update_playing()` | Current top-down gameplay loop. Must call forward scene systems. |
| 1691–1710 | `update_player()` | Current 2D movement/autofire. Rewrite to 3D corridor movement. |
| 1711–1839 | weapon helpers | Current 2D muzzle/hit/laser/bullets. Rewrite as 3D hardpoint VFX. |
| 1867–1901 | branching | Keep concept, but convert route branch to air corridor/weather corridor choice. |
| 1902–2145 | spawning/enemy/boss/fire | Current 2D waves. Rewrite with 3D enemy director. |
| 2153–2191 | bullet updates | Current 2D bullet arrays. Rewrite as 3D projectiles/trails. |
| 2192–2287 | support drops/pickups | Convert to forward-air abilities and 3D pickup/lock-on systems. |
| 2288–2329 | effects/hazards | Split into 3D VFX and HUD effects. |
| 2392–2489 | collision/kill enemy | Rewrite for 3D hit volumes/raycast/projectile collisions. |
| 2747–2783 | `_draw()` | Must stop rendering gameplay world; only UI/HUD overlays remain. |
| 2873–2892 | weather overlay | Convert rain/visibility to 3D camera/world FX plus light HUD overlay. |
| 2908–2960 | `draw_game_world()` | Delete as gameplay renderer; maybe retain debug disabled during transition. |
| 3395–3425 | `draw_hud()` | Refit for reticle/lock-on/boss bar/forward air abilities. |

### 4.3 Delete after replacement is playable

These sections are direct legacy and should not survive final cleanup.

| Lines | Function/section | Delete reason |
| --- | --- | --- |
| 39, 44–45 | `car_defs`, `selected_car`, car tab state | No car/garage direction. |
| 52, 77 | `convoy`, `convoy_damage_taken` | No convoy objective. |
| 113–135 | ground car state vars | No ground chase. |
| 540–548 | `make_car_defs()` | No car roster. |
| 669–689 | active car functions | No car progression. |
| 780–796 | `car_stat_multiplier()` | No car stats. |
| 1080–1094 | `make_convoy_vehicle()` | No convoy. |
| 1107–1145 | `start_ground_phase`, cleanup ground scene | No ground phase. |
| 1268–1640 | setup/update ground chase and support jet switch | No car/chase/prologue. |
| 1641–1654 | `enter_air_phase()` | No transition from ground to air. Stage starts in forward air scene. |
| 1841–1866 | route/convoy movement functions | No 2D route/convoy movement. |
| 2107–2127 | shoot at convoy/spread at convoy | No convoy target logic. |
| 2330–2348 | convoy turrets | No convoy. |
| 2501–2520 | `damage_convoy()` | No convoy fail state. |
| 2568–2618 | convoy helper functions | No convoy. |
| 2804–2872 | draw background/road/backdrop | Old static/canvas arena. |
| 2972–3109 | draw player/convoy/enemy/boss/hazard/effect as 2D gameplay | Replace with 3D scene/HUD only. |
| 3267–3291 | car-capable hangar preview | Replace with 3D aircraft preview. |
| 3368–3394 | ground overlay | No ground phase. |

---

## 5. Variable/State Migration Plan

### 5.1 Keep or rename

| Current | Target |
| --- | --- |
| `state = GameState.PLAYING` | Keep, but means forward air combat. |
| `player` dictionary | Replace with `forward_player`/`ForwardPlayerRig` state facade. |
| `stage`, `stage_index`, `loadout` | Keep as mission config. |
| `stage_score`, `stage_stars`, `kills` | Keep as scoring. |
| `stage_wind_mod`, weather timers | Keep concept, move effect application to forward systems. |
| `screen_flash`, `screen_shake`, `warning_text` | Keep for feedback, but camera shake moves to CameraRig. |

### 5.2 Remove after migration

```text
DIRECT_SKY_FORCE_MODE
CONVOY_RADIUS
ROAD_WIDTH
car_defs
selected_car
convoy
ground_* variables
route_x_for_*
convoy_* helpers
```

### 5.3 New state target

```text
forward_scene: Node3D
forward_player_state: Dictionary or class facade
mission_mode = "forward_air_combat"
camera_mode = "chase_behind_above"
player_model_kind = "glb"
forward_speed
corridor_position = Vector2(x, y)
lock_on_targets
boss_phase
weather_cells_3d
```

---

## 6. Phase 1 Implementation Cut Points

Phase 1 tetap besar, tetapi implementasinya harus aman dan berurutan. Jangan mencoba seluruh game selesai dalam satu commit.

### Phase 1A — Add new script and node

Create:

```text
scripts/forward_air_scene_3d.gd
```

Expected minimal API:

```gdscript
func setup(owner_main: Node) -> void
func start_mission(stage_data: Dictionary, loadout_data: Dictionary, aircraft_data: Dictionary) -> void
func stop_mission() -> void
func update_forward(delta: float, input_state: Dictionary) -> void
func get_bridge_state() -> Dictionary
```

### Phase 1B — Main integration

In `main.gd`:

- add `var forward_scene: Node3D`;
- instantiate/add child after loading or during `_ready()`;
- in `start_stage()`, call `forward_scene.start_mission(...)` instead of initializing old 2D route/convoy;
- in `update_playing()`, call `forward_scene.update_forward(...)`;
- in `_draw()`, do not call `draw_game_world()` while forward scene active; only HUD/debug overlay.

### Phase 1C — Temporary compatibility

Allowed temporarily:

- old loading/title/briefing/hangar screens;
- old save with migration fallback;
- old export root files until next export.

Forbidden in Phase 1 visible gameplay:

- car/convoy prologue;
- top-down player sprite;
- static background gameplay image;
- upward canvas scroll as the main motion.

---

## 7. QA Checklist for Phase 1

### Phase 1 scene/camera QA

Browser/preview must prove:

- [ ] canvas remains 720x1280;
- [ ] `window.ForceWarBridge.state.missionMode == "forward_air_combat"`;
- [ ] active scene includes `ForwardAirScene3D`;
- [ ] active camera mode reports `chase_behind_above` or equivalent;
- [ ] no car/convoy UI appears after launch.

### Phase 1 aircraft/control QA

- [ ] player aircraft is GLB/model instance, not PNG;
- [ ] camera is behind and slightly above aircraft;
- [ ] aircraft occupies lower third of screen;
- [ ] nose points toward forward depth;
- [ ] movement/roll is visible when steering.

### Later phase arena/weapon QA

- [ ] arena has far/mid/near depth layers;
- [ ] cloud/warzone chunks move as forward flight;
- [ ] weapon VFX emits from GLB hardpoints;
- [ ] player fire has cyan/white core and strong trail;
- [ ] enemy fire uses red/orange language.

---

## 8. Forbidden Runtime Checklist

Before each gameplay commit after Phase 1 implementation starts, run targeted grep and visual check.

Forbidden in active runtime flow:

```text
start_ground_phase()
setup_ground_scene()
update_ground_chase()
enter_air_phase()
make_convoy_vehicle()
damage_convoy()
draw_convoy_vehicle()
draw_road()
draw_game_world() as gameplay renderer
assets/rendered/player_stormhawk.png as player aircraft
assets/rendered/background_*.png as gameplay arena
```

Forbidden user-facing terms except audit/changelog/docs:

```text
car prologue
ground chase
convoy escort
top-down aircraft gameplay
storm convoy
```

---

## 9. Phase 1 Prep Exit Summary

Phase 1 prep is complete when the following are true:

- [x] `scripts/main.gd` sections are mapped into keep/rewrite/delete.
- [x] New script/module layout is defined.
- [x] One-file vs split decision is made: split new systems; keep `main.gd` as temporary shell.
- [x] Forbidden runtime list is written.
- [x] Visual QA checklist is written.
- [x] No gameplay behavior is changed in this phase.

Next implementation work: **Phase 1 — Core Forward Flight Rebuild**.
