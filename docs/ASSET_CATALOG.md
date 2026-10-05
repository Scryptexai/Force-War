# Force War — Asset Catalog for Forward 3D Redesign

Tanggal redesign lock: 2026-10-05

Asset policy baru: **gameplay utama harus memakai GLB/3D**, terutama player aircraft, enemy aircraft, boss, missiles, dan arena chunks. PNG lama tidak boleh lagi menjadi representasi gameplay player plane atau arena utama.

## 1. Visual Reference

| File | Role | Policy |
| --- | --- | --- |
| `gameplay_visual_lock_build.jpg` | Visual target/mood lock: cinematic storm air battle, boss, missiles, lasers, explosions, 9:16 UI | Reference only. Do not use as static gameplay background. |

## 2. Target GLB Gameplay Assets

### 2.1 Player Aircraft — Required

Belum final dan harus dibuat pada implementation pass:

| Target file | Role | Requirement |
| --- | --- | --- |
| `assets/models/player_stormhawk.glb` | Main balanced fighter | Full 3D fuselage, cockpit, wings, cyan emissive strips, engine sockets, weapon hardpoints |
| `assets/models/player_thunder_warden.glb` | Heavy/storm aircraft | Larger frame, armor plating, lightning rod profile, heavier wing cannons |
| `assets/models/player_razorwing.glb` | Fast/agile aircraft | Slim swept wings, high speed afterburner, lighter body |
| `assets/models/player_aegis_medic.glb` | Support/defense aircraft | Utility pods, shield projector, support hardpoints |

Minimum shared requirements:

- Model is GLB, not PNG/billboard.
- Has named or consistent child transforms for hardpoints.
- Has engine exhaust locations.
- Has material/emissive identity matching Force War palette.
- Has collision proxy or separate hit volume.

### 2.2 Enemy Aircraft / Drones — Required

| Target file | Role |
| --- | --- |
| `assets/models/enemy_interceptor.glb` | Fast forward-lane fighter |
| `assets/models/enemy_storm_drone.glb` | Cloud/radar/weather drone |
| `assets/models/enemy_gunship.glb` | Heavy turret carrier |
| `assets/models/enemy_bomber.glb` | Missile/bomb platform |
| `assets/models/enemy_rotor_vtol.glb` | Helicopter/VTOL style side attacker |

### 2.3 Boss / Set Piece — Required

| Target file | Role |
| --- | --- |
| `assets/models/boss_dreadnought_leviathan.glb` | Screen-depth air fortress/dreadnought with central cannon |
| `assets/models/boss_turret_cannon.glb` | Reusable turret hardpoint |
| `assets/models/boss_missile_pod.glb` | Missile barrage hardpoint |
| `assets/models/boss_weather_core.glb` | Lightning/weather weakpoint core |

Boss must be a 3D object ahead of player, not a top overlay image.

### 2.4 Forward Arena Chunks — Required

| Target file | Role |
| --- | --- |
| `assets/models/arena_storm_cloud_bank.glb` | Large moving cloud volume/chunk |
| `assets/models/arena_ocean_warzone_chunk.glb` | Ocean/ship/fire layer below flight path |
| `assets/models/arena_burning_city_chunk.glb` | Delta/city warzone below flight path |
| `assets/models/arena_debris_field.glb` | Near/mid debris and battlefield clutter |
| `assets/models/arena_smoke_column.glb` | Reusable smoke/fire column anchor |

## 3. Current GLB Inventory

| File | Current status | New policy |
| --- | --- | --- |
| `assets/models/player_stormhawk.glb` | Phase 1 player aircraft GLB placeholder, integrated in `ForwardAirScene3D` | Active first-pass gameplay player model; replace/detail later, but keep GLB requirement |
| `assets/models/support_jet.glb` | Existing low-poly jet | Can be used as temporary wingman/reference, not final player model |
| `assets/models/air_arena_tile.glb` | Existing low-poly terrain/water/runway tile | Can be studied/reworked into forward arena chunks; current vertical/tile setup is not final |
| `assets/models/air_cloud_cluster.glb` | Existing low-poly cloud cluster | Can be reused as temporary cloud chunk if placed in forward 3D depth |
| `assets/models/player_car.glb` | Legacy ground chase car | Deprecated; remove after code rewrite |
| `assets/models/enemy_car.glb` | Legacy ground chase car | Deprecated; remove after code rewrite |
| `assets/models/convoy_car.glb` | Legacy convoy car | Deprecated; remove after code rewrite |

## 4. PNG / Rendered Asset Policy

PNG can remain for:

- logo/wordmark;
- loading/splash concept art;
- app icon/favicon;
- UI icons if no GLB/particles required;
- documentation/reference.

PNG must not be used for:

- player aircraft gameplay model;
- main enemy aircraft gameplay model;
- boss model;
- gameplay arena background as a static photo;
- fake 2D overlay that replaces 3D world.

### Current PNG Inventory Policy

| Files | Policy |
| --- | --- |
| `assets/rendered/logo_force_war_wordmark.png` | Keep for branding/loading |
| `assets/rendered/web_boot_splash_force_war.png` | Keep for Web splash if branding still matches |
| `assets/rendered/app_icon_force_war.png`, `index*.png` | Keep for app/browser icons |
| `assets/rendered/loading_*.png` | Keep only as loading concept art if no convoy/car mismatch is visible; otherwise regenerate |
| `assets/rendered/player_stormhawk.png` | Deprecated for gameplay; replace with GLB |
| `assets/rendered/enemy_*.png` | Deprecated for gameplay; replace with GLB |
| `assets/rendered/boss_aegis_weather_engine.png` | Deprecated for gameplay; replace with boss GLB |
| `assets/rendered/background_*.png` | Deprecated for gameplay arena; may remain as menu/loading reference only |
| `assets/rendered/convoy_*.png` | Deprecated; remove after code rewrite |
| `assets/rendered/support_*.png` | UI icon/reference only; gameplay pods should become 3D/particles if visible in mission |

## 5. SVG Policy

SVG files are legacy editable references/icons. They are not final gameplay assets.

| Folder | Policy |
| --- | --- |
| `assets/air/*.svg` | Deprecated for gameplay; can be reference only |
| `assets/ground/*.svg` | Deprecated for gameplay |
| `assets/convoy/*.svg` | Deprecated and scheduled removal |
| `assets/support/*.svg` | Possible UI icon source only |
| `assets/weather/*.svg` | Keep if used as small UI weather icons |

## 6. VFX Asset Requirements

Gameplay VFX can be procedural/particle-based, but must be authored for 3D chase camera.

Required VFX modules:

- player afterburner flame and vapor trail;
- cyan main cannon stream;
- wing cannon bolt trail;
- micro missile rocket + smoke trail;
- overcharge lightning laser;
- blue hex/electric shield bubble around GLB;
- red/orange enemy bullets;
- boss cannon charge beam;
- 3D explosion burst with smoke/debris;
- rain sheets, lightning flash, cloud concealment.

## 7. Cleanup Rule

Legacy asset deletion is safe only after code no longer references the file. Before deleting, run:

```bash
grep -RIn "asset_file_name" scripts scenes project.godot export_presets.cfg
```

Target final state:

- gameplay assets in `assets/models/` and particle/VFX systems;
- `assets/rendered/` mostly branding/UI/loading;
- no convoy/car asset in active export;
- no static aircraft photo in gameplay.
