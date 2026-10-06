# Phase 3 — Arena Gameplay/VFX First Pass Report

Date: 2026-10-05
Branch: `arena/01a100ae-force-war`

## Status

**Completed as a first Phase 3 production chunk.**

This is not the full Phase 3 combat package yet. It adds visible browser-verifiable arena gameplay/VFX improvements: Blender boss asset, Blender deck modules, authored projectile/explosion/smoke/shield sprites, and a cleaner forward HUD. Full hardpoint weapon logic, enemy damage, boss phases, scoring hooks, and final asset polish remain active Phase 3 work.

## Changed Runtime Direction

The active forward-air mission now avoids unclear primitive/overlay clutter as the main visual language:

- player/enemy shots use authored PNG VFX sprites on 3D textured quads;
- boss carrier uses a Blender-authored GLB instead of only runtime primitive boxes;
- deck battlefield details use a Blender-authored GLB cluster plus authored deck panel texture;
- explosion, smoke, shield, and reticle visuals use authored sprites;
- the forward HUD keeps only player HP/shield, boss HP, progress, one reticle sprite, and a compact weather strip.

## New Assets

| Asset | Purpose |
| --- | --- |
| `assets/models/boss_dreadnought_leviathan.glb` | Blender-authored dreadnought boss with idle/core pulse animations and muzzle/weakpoint sockets |
| `assets/models/arena_battle_deck_cluster.glb` | Blender-authored battlefield/deck module with AA turrets, radar mast, beacon animations, and sockets |
| `assets/vfx/hero_cyan_shot.png` | Player cyan shot lanes/pulses/friendly tracers |
| `assets/vfx/enemy_orange_shot.png` | Enemy/boss orange shot lanes/laser telegraphs |
| `assets/vfx/explosion_fireball.png` | Ground fires and explosion bursts |
| `assets/vfx/smoke_plume.png` | Smoke columns and missile/smoke trails |
| `assets/vfx/shield_bubble.png` | Support/wingman shield bubbles |
| `assets/vfx/reticle_lock.png` | Clean authored HUD reticle |
| `assets/vfx/arena_deck_panel.png` | Textured deck/sea panels below the flight path |

## Blender Verification

Generated with the sandbox Blender `bpy 4.5.14 LTS` runtime:

- `boss_dreadnought_leviathan.glb`: 447,184 bytes, 53 nodes, 48 meshes, animations `BossDreadnought_IdleHover` and `BossCore_ChargePulse`, sockets `Boss_Muzzle_Core`, `Boss_Muzzle_Left`, `Boss_Muzzle_Right`, `Boss_WeakPoint_Core`.
- `arena_battle_deck_cluster.glb`: 301,216 bytes, 31 nodes, 27 meshes, beacon pulse animations, sockets `Deck_AA_Muzzle_00`, `Deck_AA_Muzzle_01`, `Deck_Smoke_Anchor`.

## Runtime Bridge Values

Browser QA now expects these fields from `window.ForceWarBridge.state`:

```text
missionMode=forward_air_combat
cameraMode=chase_behind_above
playerModel=glb
cloudGeometry=false
enemyHeroJetSource=blender_ready_glb
enemyHeroJetAnimation=EnemyJet_AttackPass_Loop
shotAnimation=asset_sprite_hero_enemy_lanes
bossArenaAsset=boss_dreadnought_leviathan_glb
arenaAssetDeckCluster=true
projectileAssetSprites=true
cleanArenaOverlay=true
playerScaleMode=reduced_mobile_readable
```

## Validation Run

Latest validation for this chunk:

```bash
/tmp/force-war-godot-4.6.2/Godot_v4.6.2-stable_linux.x86_64 --headless --path . --check-only --script scripts/forward_arena_director.gd
/tmp/force-war-godot-4.6.2/Godot_v4.6.2-stable_linux.x86_64 --headless --path . --check-only --script scripts/main.gd
/tmp/force-war-godot-4.6.2/Godot_v4.6.2-stable_linux.x86_64 --headless --path . --import --quit
./tools/export_web.sh
npm run vercel-build
npm run qa:forward
npm run qa:web
```

## What Remains In Phase 3

- Move current VFX orchestration into a dedicated weapon/enemy/boss combat director.
- Spawn player shots from real GLB muzzle/hardpoint sockets.
- Add collision/hit detection, enemy HP, boss weakpoint damage, hit flash/sparks, and scoring.
- Add boss attack phases with safe gaps instead of ambient-only lane telegraphs.
- Add missile model/logic and overcharge laser tied to weather.
- Continue replacing any visible legacy/primitive modules with GLB, particles, or authored sprites.

## 2026-10-06 continuation — boss weakpoint and hit feedback

After the Phase 2 GLB muzzle/socket foundation, Phase 3 resumes with boss gameplay readability:

- binds the Dreadnought visual target to GLB socket `Boss_WeakPoint_Core` when available;
- adds one clean authored reticle quad on the current targetable boss part;
- adds a pooled sprite impact layer for player projectile hit events;
- keeps impact feedback asset-backed (`reticle_lock.png`, `explosion_fireball.png`) and avoids reintroducing full-screen/vertical beam clutter;
- exports bridge fields for QA: `phase3GameplayVFXPass`, `bossWeakpointSocketBinding`, `bossGLBWeakpointSocketFound`, `bossImpactVFXPool`, `bossImpactEvents`, and `bossImpactVFXActive`.

This still is not the final Phase 3 boss package; turret hardpoint fire, phase-specific destruction art, scoring, and final boss encounter pacing remain pending.

## 2026-10-06 continuation — boss muzzle hardpoint fire

The next Phase 3 chunk moves boss outgoing fire from generic lane-only spawning toward GLB hardpoint spawning:

- discovers `Boss_Muzzle_Left`, `Boss_Muzzle_Core`, and `Boss_Muzzle_Right` in the Dreadnought GLB instance;
- renders three thin orange forward fire lanes from those socket positions;
- passes socket positions into the logical projectile manager so boss bullets report `logicalBossProjectileOrigin=glb_boss_muzzle_socket`;
- keeps the fire non-homing and pattern/lane based, avoiding the rejected continuous chasing behavior;
- exports QA fields for socket count, VFX activity, socket fire events, and logical socket spawns.

This remains a gameplay-readability pass; final turret meshes, destruction animation per part, and balanced safe-gap patterns are still future Phase 3 work.
