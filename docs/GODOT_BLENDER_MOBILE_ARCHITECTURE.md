# Force War — Godot + Blender Mobile Shooter Architecture

This document adapts the requested Godot/Blender mobile-first shooter architecture to the current Force War repository.

## Version lock for this branch

The current branch is still locked to **Godot 4.6.2 stable** because the repo includes the 4.6.2 editor/export template setup and the prior project constraint explicitly required 4.6.2. The architecture below is renderer- and data-oriented so it can be upgraded later, but this branch will not silently switch to another engine version without an explicit migration task.

Blender production remains based on **Blender 4.5 LTS / bpy 4.5.14** for reproducible GLB generation in the sandbox.

## Target platform split

```text
One gameplay codebase
├── Android production target: Mobile renderer / Vulkan path
└── Web preview target: Compatibility renderer / WebGL path
```

The current browser build remains a preview/debug target. It is useful for controls, flow, QA state, and visual direction, but Android device profiling must become the final visual/performance gate later.

## Current migration state

| System | Current status |
| --- | --- |
| Chase-camera forward flight | Active in `ForwardAirScene3D` |
| Textured player GLB | First production pass active |
| Textured boss/deck GLBs | First production pass active |
| BattlefieldDirector concept | Existing `ForwardArenaDirector` acts as the active battlefield director |
| Renderer-aware VFX | Started with pooled MultiMesh projectile visuals plus existing textured quads |
| Projectile architecture | `ProjectileVisualPool3D` batches 84 bolt visuals using MultiMesh, and `ProjectileManager3D` now owns a 140-slot logical enemy bullet pool with no physics body per bullet |
| Data-driven weapons/patterns | JSON projectile contracts added under `data/projectiles/`; runtime logical manager loads those definitions |
| Boss phase/damage model | `BossPhaseController` active with shield, wings, turrets, and core health; HUD boss bar reads real boss ratio |
| Quality manager | Not implemented yet |
| Android APK/AAB | Not implemented in this branch yet |

## Architecture direction

```text
GameRoot
├── GameManager
├── ForwardAirScene3D
├── ForwardArenaDirector      # current BattlefieldDirector runtime
├── ProjectileVisualPool3D    # batched renderer-facing projectile visuals
├── Combat/ProjectileManager  # next: logical pooled bullets + collision
├── BossPhaseController       # next: boss health parts + phases
└── UI / HUD
```

## Rule: no false asset claims

A feature is not considered production-ready until the repo contains:

1. a source asset or generation script,
2. the exported runtime GLB/texture/sprite,
3. Godot import/export success,
4. browser screenshot proof,
5. QA bridge state proving the runtime path is active.

## Next implementation chunk

The next major chunk should implement the actual logical combat layer behind the current visual layer:

- expand `ProjectileManager3D` into full player/enemy/missile/laser gameplay pools;
- convert JSON projectile contracts into Resource-based editor tooling when the schema stabilizes;
- add boss attack pattern scheduling for phase 2/3, not just health-state progression;
- debug commands for bullet count, boss phase, and quality tier;
- later: Android export and device profiling.
