# Phase 0 Completion Report — Direction Lock, Audit, Code Map

Tanggal: 2026-10-05
Branch: `arena/01a100ae-force-war`
Phase: **Phase 0 — Direction Lock, Audit, Code Map**
Status: **Done**

Phase 0 adalah phase fondasi sebelum coding gameplay rebuild. Fokusnya bukan membuat gameplay baru dulu, tetapi mengunci arah, membuang arah lama dari roadmap aktif, dan menyiapkan cut map supaya Phase 1 bisa langsung mengerjakan paket besar: player GLB + chase camera + forward flight scene.

---

## 1. Phase 0 Goal

Phase 0 memastikan Force War tidak lagi bergerak sebagai vertical/top-down shooter lama, tidak lagi memakai convoy/car prologue, dan tidak lagi memperlakukan PNG/static aircraft sebagai gameplay target.

Target yang dikunci:

- Player aircraft harus GLB 3D.
- Camera harus dari belakang dan sedikit di atas player aircraft.
- Game harus bergerak maju ke depan dalam depth 3D.
- Arena harus 3D storm battlefield, bukan static photo/parallax.
- Weapon VFX harus keluar dari hardpoint model.
- Car/convoy/top-down flow harus deprecated dan masuk cleanup plan.

---

## 2. Phase 0 Deliverables

| Deliverable | File | Status |
| --- | --- | --- |
| Visual target lock | `gameplay_visual_lock_build.jpg` | Done — verified 720x1280 |
| Third-person forward air combat direction | `docs/THIRD_PERSON_AIR_COMBAT_REDESIGN.md` | Done |
| Big phase rebuild roadmap | `docs/REBUILD_ROADMAP_AND_MILESTONES.md` | Done |
| Code rebuild map | `docs/CODE_REBUILD_MAP.md` | Done |
| Repo cleanup audit | `docs/REPO_CLEANUP_AUDIT.md` | Done |
| Asset policy rewrite | `docs/ASSET_CATALOG.md` | Done |
| Forward 3D VFX research | `docs/FX_RESEARCH.md` | Done |
| Mobile forward-flight UI/UX flow | `docs/UI_UX_FLOW_AUDIT.md` | Done |
| Forward-flight UI/UX research | `docs/UI_UX_RESEARCH.md` | Done |
| Web build flow retained | `docs/WEB_BUILD_FLOW.md` | Done |
| README direction update | `README.md` | Done |

---

## 3. Repo Cleanup Completed in Phase 0

Removed old helper/generator tools that encouraged the previous SVG/convoy/car/top-down workflow:

```text
tools/generate_assets.py
tools/generate_glb_assets.py
tools/serve_web.py
```

Important note: old gameplay code and legacy assets are not physically removed yet because the current Web baseline still references them. They are marked as legacy/quarantine and will be removed in Phase 4 after the forward 3D replacement is playable.

---

## 4. Code Map Summary

`docs/CODE_REBUILD_MAP.md` categorizes `scripts/main.gd` into three groups:

### Keep temporarily

- loading/title/briefing shell;
- Web bridge;
- save utility shell;
- stage/weather/loadout data concepts;
- shared text/panel UI helpers.

### Rewrite

- `start_stage()`;
- `update_playing()`;
- player control;
- weapon system;
- enemy/boss systems;
- HUD;
- weather application;
- old 2D gameplay draw path.

### Delete after replacement is playable

- ground car phase;
- convoy logic;
- car progression;
- top-down gameplay renderer;
- convoy/car UI;
- active dependency on PNG player/enemy gameplay assets.

---

## 5. Phase 0 Acceptance Gate

| Gate item | Result |
| --- | --- |
| Direction is locked to forward 3D air combat | Passed |
| Visual target reference exists | Passed |
| Player GLB requirement documented | Passed |
| Chase camera requirement documented | Passed |
| Old car/convoy/top-down setup marked deprecated | Passed |
| Code map exists before gameplay rewrite | Passed |
| Big phase roadmap exists | Passed |
| Web pipeline remains intact | Passed |

Phase 0 is considered complete.

---

## 6. Validation Run

Commands/results from Phase 0 related work:

```text
git diff --check        -> passed
npm run vercel-build    -> passed
identify gameplay_visual_lock_build.jpg -> JPEG 720x1280
```

No gameplay runtime change is intentionally introduced by Phase 0.

---

## 7. Phase 1 Entry Criteria

Phase 1 may begin because:

- Phase 0 direction lock is complete;
- code cut points are mapped;
- current Web baseline is still valid;
- next output is clear: browser-visible forward 3D flight.

Phase 1 must not stop at docs or an invisible skeleton. It must produce visible gameplay proof:

```text
Loading/Title/Briefing -> Launch -> ForwardAirScene3D
player GLB visible
camera behind/slightly above
movement in 3D corridor
forward depth readable
no car/convoy/top-down gameplay visible
```

---

## 8. Next Work Order

Next phase to execute:

```text
Phase 1 — Core Forward Flight Rebuild
```

First implementation tasks:

1. Create `scripts/forward_air_scene_3d.gd`.
2. Create/import `assets/models/player_stormhawk.glb` placeholder 3D model.
3. Spawn `ForwardAirScene3D` from the current main shell.
4. Add chase camera behind/slightly above.
5. Add corridor movement and roll/pitch visual response.
6. Add minimal forward depth markers/cloud placeholders.
7. Export Web, run QA, and restart preview.
