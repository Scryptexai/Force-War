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

Validation for this continuation passed on Godot 4.6.2 stable:

- `--check-only` passed for `forward_air_scene_3d.gd`, `forward_arena_director.gd`, `projectile_manager_3d.gd`, and `projectile_visual_pool_3d.gd`;
- `git diff --check` passed;
- `./tools/export_web.sh` passed with root Web export files updated (`index.pck` 13,632,528 bytes);
- `npm run vercel-build`, `npm run qa:forward`, and `npm run qa:web` passed;
- manual browser capture was saved to `qa/screenshots/phase3_boss_muzzle_hardpoint_fire.png` with state proof in `qa/screenshots/phase3_boss_muzzle_hardpoint_fire_state.json`.

Captured state included `bossMuzzleSocketBinding=glb_boss_muzzle_socket_runtime`, `bossMuzzleSocketCount=3`, `bossSocketFireEvents=51`, `logicalBossProjectileOrigin=glb_boss_muzzle_socket`, `logicalBossMuzzleSocketSpawns=43`, and `bossHardpointFireNonHoming=true`.

## 2026-10-06 completion — Phase 3 debug and QA gate

The current Phase 3 boss combat/VFX slice is now debug-locked and browser-QA verified. Added a dedicated `npm run qa:phase3` harness that boots the root Web export, enters the forward-air mission on a 720x1280 mobile viewport, waits for boss weakpoint + muzzle fire + logical projectile events, captures a screenshot, and writes state/summary proof.

New proof files:

- `qa/screenshots/phase3_debug_qa_final.png`
- `qa/screenshots/phase3_debug_qa_final_state.json`
- `qa/screenshots/phase3_debug_qa_final_summary.json`

Final Phase 3 debug state included:

```text
phase3DebugStatus=boss_weakpoint_muzzle_fire_debug_locked
phase3QAContract=phase3_debug_browser_v1
phase3VisualSafety=clean_hud_no_vertical_columns_no_cloud_geometry
bossMuzzleSocketNames=Boss_Muzzle_Left,Boss_Muzzle_Core,Boss_Muzzle_Right
bossMuzzleSpreadX=8.39808440208435
bossSocketFireEvents=30
logicalBossMuzzleSocketSpawns=21
bossImpactEvents=20
playerProjectileHits=20
```

The near-camera rain-sheet geometry is disabled for this debug lock (`rainGeometryMode=haze_only_no_vertical_columns`, `nearRainSheetCount=0`) because the previous capture could read as vertical blue columns. Rain remains a gameplay variable through visibility and wind/drift state.

Validation passed with Godot 4.6.2 stable, root Web export, `vercel-build`, `qa:forward`, dedicated `qa:phase3`, and `qa:web`. This closes Phase 3 debug/QA for the current boss combat slice; final turret art, destructible hardpoints, safe-gap balancing, and full boss pacing remain future production work.

## 2026-10-06 continuation — destructible hardpoint phase transition

The next Phase 3 production chunk turns the boss from a single shield target into a browser-verifiable multi-step encounter:

- weakpoint hits now apply a tuned multiplier to shield/turret parts so the vertical slice can actually reach later phases during QA;
- after shield destruction, target routing moves to turrets and switches the attack pattern to `turret_crossfire_pool_v1`;
- after turret destruction, the boss enters `PHASE_3_CORE_EXPOSED` and routes the reticle to the core;
- destroyed parts spawn socket-positioned damage/smoke markers via `bossPartDamageVFX=socket_part_damage_markers`;
- the exposed core uses a lower pacing multiplier so the QA screenshot captures phase 3 before the boss instantly dies;
- legacy near-camera cyan pulse nodes are disabled (`legacyNearCameraCyanPulseNodes=0`) after screenshot review showed they could still create giant vertical-looking sheets.

Final state proof for this chunk is stored in `qa/screenshots/phase3_debug_qa_final_state.json` and summary in `qa/screenshots/phase3_debug_qa_final_summary.json`. Latest browser QA metrics included:

```text
phase3BossCombatChunk=destructible_hardpoint_phase_transition
bossPhase=3
bossPhaseName=PHASE_3_CORE_EXPOSED
bossPhaseTransitionCount=2
bossTargetablePart=core
bossDestroyedParts=2
bossLatestDestroyedPart=turrets
bossDestroyedPartVFXCount=2
bossWeakpointDamageEvents=73
bossCoreRatio=0.810341463414635
bossSocketFireEvents=62
logicalBossMuzzleSocketSpawns=62
bossImpactEvents=73
playerProjectileHits=73
```

Validation passed with Godot 4.6.2 stable, root Web export, `vercel-build`, `qa:forward`, updated `qa:phase3`, `qa:web`, and screenshot/manual inspection.
