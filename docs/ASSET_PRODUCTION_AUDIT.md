# Force War — Asset Production Audit (2026-10-05)

This audit was added after the visual QA correction that the arena still looked code-generated. It separates real runtime assets from placeholders and states what was actually produced with Blender.

## What changed in this pass

- Bootstrapped and verified headless Blender `bpy 4.5.14 LTS` runtime in the sandbox.
- Added production texture sources under `assets/source_textures/` and kept that folder out of Godot import with `.gdignore`.
- Generated new textured Blender GLBs with `tools/blender_create_textured_air_assets.py`:
  - `assets/models/player_stormhawk.glb`
  - `assets/models/boss_dreadnought_leviathan.glb`
  - `assets/models/arena_battle_deck_cluster.glb`
- Replaced the old code-looking projectile sprites with larger image-authored VFX sprites:
  - `assets/vfx/hero_cyan_shot.png`
  - `assets/vfx/enemy_orange_shot.png`
- Added a textured storm-ocean material plane in the 3D arena:
  - `assets/vfx/storm_ocean_material.jpg`
- Kept the prior cinematic matte as a background art layer, but it is not treated as a substitute for 3D assets.

## Runtime asset proof

| Asset | Proof after this pass |
| --- | --- |
| `player_stormhawk.glb` | Blender-generated GLB, ~264 KB, includes one embedded/extracted livery texture source. |
| `boss_dreadnought_leviathan.glb` | Blender-generated GLB, ~578 KB, includes carrier-deck and hull textures, plus `BossDreadnought_IdleHover` and `BossCore_ChargePulse` clips. |
| `arena_battle_deck_cluster.glb` | Blender-generated GLB, ~557 KB, includes carrier-deck and hull textures, turret/radar modules, sockets, beacon animation clips. |
| `hero_cyan_shot.png` | Image-authored cyan plasma bolt sprite used on 3D quads for player shot lanes/pulses. |
| `enemy_orange_shot.png` | Image-authored orange enemy/boss bolt sprite used on 3D quads. |
| `storm_ocean_material.jpg` | Image texture applied to Godot 3D floor planes below the flight corridor. |

## What is still placeholder / not final

- Enemy waves still use the uploaded hero jet as an enemy placeholder, prepared by the existing Blender pipeline.
- The boss is now textured and Blender-authored, but still a first production pass, not a final high-poly asset.
- The arena uses textured deck modules and ocean planes, but still needs more real 3D set-piece assets: ships, buildings, hangars, antenna arrays, missile pods, debris fields.
- Combat logic is still not a complete boss fight: damage phases, hardpoint targeting, missile models, hit reactions, and progression need another gameplay pass.
- Old convoy/car assets still exist in the repository for legacy quarantine, but they are not active in direct forward-air gameplay.

## Validation gate added

`qa/forward-flight-browser-qa.mjs` now requires:

- `cinematicMatteAsset === true`
- `stormOceanTextureAsset === true`
- `texturedBlenderAssets === true`
- `projectileAssetSprites === true`
- `projectileVisualPool === true` and `projectilePoolCount >= 80`
- `cloudGeometry === false`
- `canvas === 720x1280`

Automated QA is still not enough by itself. Browser screenshot review remains required before claiming visual quality. The current projectile pool now has two layers: a renderer-facing MultiMesh visual pool and a `ProjectileManager3D` logical pool with cheap radius checks. Player plasma now registers pooled logical hits against boss parts, and `BossPhaseController` exposes data-driven attack-pattern scheduling. Missiles, lasers, authored telegraphs, and Android device profiling remain future work.

## Latest verified build facts

- Godot: `4.6.2.stable.official.71f334935`
- Web export root output:
  - `index.html` 5638 bytes
  - `index.js` 315759 bytes
  - `index.wasm` 37695054 bytes
  - `index.pck` 13588376 bytes
- `index.pck` remains below the 16 MB mobile boot guard.
- Chromium capture after this pass showed textured storm-ocean floor, textured deck modules, visible plasma shot lanes, and forward-air GLB gameplay state with `texturedBlenderAssets=true`.

## Foundation correction note — player GLB authenticity

After user feedback that the generated `player_stormhawk.glb` was visually unacceptable as a replacement for the uploaded aircraft, the Phase 1 starter correction now points the runtime player model at `assets/models/enemy_hero_jet_blender_ready.glb`, the Blender-prepared derivative of the uploaded `assets/models/enemy_hero_jet.glb`. The generated Stormhawk remains only a fallback. Web keeps the prepared derivative to avoid reintroducing the oversized/slow PCK while preserving the uploaded GLB as the source contract. This is a correction starter, not a final art approval; scale/orientation and hardpoint sockets still need screenshot and Blender-source verification.

## Foundation direction/cleanliness pass

Tahap 1 correction now aligns the Blender-prepared uploaded player GLB from local negative-Y into the gameplay negative-Z forward axis, disables visible runtime fallback afterburner boxes, and reduces decorative vertical beams/explosion/shield clutter in the arena. QA now checks `playerModelAlignment`, `backgroundClutterMode=foundation_clean`, and `legacyVerticalShotColumns=false`. This remains a correction pass, not a final art-quality claim.

## Tahap 2 socket binding note

The player shot origin is now bound to named sockets from `assets/models/enemy_hero_jet_blender_ready.glb`: `Muzzle_Left`, `Muzzle_Right`, and `Engine_Core`. Runtime fallback sockets remain only as safety if the GLB socket lookup fails. The arena shot pulses, player projectile visual pool spawn resets, and logical player projectile manager now consume the same hardpoint state. Browser QA now checks `playerWeaponHardpointBinding=glb_socket_runtime`, `playerGLBWeaponSocketsFound=true`, `playerShotSpawnOrigin=glb_muzzle_socket`, and `logicalPlayerShotOrigin=glb_muzzle_socket`.

## Tahap 2 visible hardpoint fire update

The next Tahap 2 pass adds visible cyan muzzle flashes and short forward tracer shards driven directly by the same GLB socket world positions as gameplay shots. The bridge reports `socketMuzzleVFX=glb_socket_cyan_forward_burst`, `socketMuzzleVFXActive=true`, and `playerShotVisibleFromSocket=true`; browser QA now fails if the socket-bound fire VFX is not active.

## Tahap 2 yaw/forward-axis correction

The visible hardpoint pass found that the prepared GLB muzzle sockets were landing camera-side after the prior Phase 1 rotation. Tahap 2 now yaws the uploaded GLB runtime instance 180 degrees after the X-axis import correction so the named `Muzzle_Left`/`Muzzle_Right` sockets sit ahead of the aircraft in world negative-Z. QA checks `playerModelAlignment=uploaded_glb_socket_muzzle_forward_world_negative_z` and fails if `playerMuzzleCenterZ` is not forward of the player rig.
