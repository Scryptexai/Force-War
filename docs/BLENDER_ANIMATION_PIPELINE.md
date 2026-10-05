# Blender Animation Pipeline — Force War

Tanggal: 2026-10-05
Status: **Required pipeline for proper animated air-war assets**

User direction: Force War should not rely on primitive placeholder geometry for the final look. Proper aircraft, enemy, boss, hardpoint sockets, and cinematic animation clips must be prepared through Blender, exported as GLB, and then controlled by Godot runtime.

---

## 1. Role Split

| Area | Blender owns | Godot owns |
| --- | --- | --- |
| Player/enemy/boss geometry | mesh detail, origin, scale, materials, sockets | instancing, gameplay movement, camera framing |
| Animation clips | attack-pass loops, engine/nozzle pulse, boss mechanical movement, muzzle flash markers | state machine, timing, collision, damage, pooling |
| Shot visuals | muzzle/socket placement and authored VFX helper meshes | projectile spawning, wind drift, hit logic, non-homing readable patterns |
| Optimization | mesh cleanup, LOD, texture baking, naming convention | import settings, runtime visibility, Web export budget |

---

## 2. Current Blender Tooling

Two repo tools are now part of the workflow:

```bash
tools/run_blender_air_pipeline.sh
tools/blender_prepare_air_combat_assets.py
```

Expected run when Blender is installed:

```bash
BLENDER_BIN=/path/to/blender tools/run_blender_air_pipeline.sh \
  assets/models/enemy_hero_jet.glb \
  assets/models/enemy_hero_jet_blender_ready.glb
```

The script imports the uploaded enemy/hero jet GLB, normalizes scale/origin, adds sockets:

- `Muzzle_Left`
- `Muzzle_Right`
- `Missile_Left`
- `Missile_Right`
- `Engine_Core`

It also adds a simple `EnemyJet_AttackPass_Loop` animation and exports a Godot-ready GLB.

> Sandbox note: this Arena runtime currently does not provide a `blender` binary and `apt` could not fetch Blender. The pipeline is committed so it can be run in any build/dev environment where Blender exists. Until Blender output is produced, Godot uses `assets/models/enemy_hero_jet.glb` directly as the enemy placeholder.

---

## 3. Asset Naming Convention

| Purpose | Path |
| --- | --- |
| Uploaded enemy source | `assets/models/enemy_hero_jet.glb` |
| Blender-prepared enemy output | `assets/models/enemy_hero_jet_blender_ready.glb` |
| Player aircraft source/final | `assets/models/player_stormhawk.glb` or future Blender-authored replacement |
| Boss dreadnought source/final | `assets/models/boss_dreadnought_leviathan.glb` |
| Temporary procedural runtime boss | `ForwardArenaDirector` boss anchor, only until boss GLB exists |

---

## 4. Immediate Visual Corrections From User Review

- Camera direction is accepted as correct.
- Player aircraft was too large on mobile; it must be smaller and leave more corridor movement space.
- Clouds should be removed from the active arena. The reference image has thin haze/fog, not repeating solid cloud chunks.
- Shot animation must be readable and moving:
  - player cyan shots must travel forward from the aircraft;
  - enemy red/orange shots must travel toward the player in readable lanes;
  - shots must not continuously chase the player.
- Enemy placeholder can use uploaded `enemy_hero_jet.glb` until proper Blender-authored enemy set is ready.

---

## 5. Roadmap Impact

The roadmap now includes a mandatory Blender asset/animation production lane before claiming the combat package complete. Phase 3 is not just code: it must include Blender-prepared GLB assets or documented placeholders with a clear replacement path.
