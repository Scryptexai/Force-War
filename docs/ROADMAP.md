# Force War — Forward 3D Air Combat Roadmap

Tanggal redesign lock: 2026-10-05

Detail rebuild step-by-step dan progress gates sekarang dicatat di `docs/REBUILD_ROADMAP_AND_MILESTONES.md`. Dokumen ini tetap menjadi roadmap ringkas/high-level.

## Visi Baru

Force War bukan lagi vertical/top-down Sky Force clone dan bukan lagi convoy/car escort. Force War sekarang diarahkan menjadi **3D forward air-combat**: player mengendalikan pesawat GLB dari kamera chase di belakang-sedikit-atas, bergerak maju ke medan perang badai, melawan drone/fighter/boss dreadnought dalam arena 3D sinematik.

## Status Realistis Saat Ini

**Build saat ini adalah baseline teknis lama, bukan target gameplay final.**

Root Web export, server, Vercel flow, loading/branding, dan beberapa sistem weather/combat lama sudah ada. Namun arah gameplay visual harus dibedah ulang:

| Area | Status realistis setelah redesign lock |
| --- | --- |
| Godot/Web pipeline | 80% — root export/server/QA sudah ada dan dipertahankan |
| Gameplay direction | 20% — target baru sudah dikunci, implementation belum dimulai |
| Camera/game feel | 5% — harus rewrite ke chase camera 3D |
| GLB aircraft gameplay | 10% — baru ada `support_jet.glb` placeholder; player GLB belum final |
| Forward 3D arena | 15% — GLB tile/cloud lama bisa direuse ide, tapi arah scroll/camera harus dirombak |
| Weapon/VFX quality | 15% — efek lama belum memenuhi target cinematic forward air war |
| UI/mobile shell | 45% — loading/title/HUD baseline ada, tapi harus disesuaikan ke forward flight |
| Legacy cleanup | 20% — docs dibersihkan; code/assets legacy masih menunggu rewrite |
| Overall menuju target baru | ±24% |

## Pilar Desain Baru

1. **3D aircraft first**
   Player plane, major enemies, missiles, and boss must be GLB/3D. PNG/sprite hanya boleh untuk logo, loading, UI icon, dan reference.

2. **Forward movement**
   Game terasa maju ke depan dalam world 3D. Tidak ada lagi scroll ke atas sebagai bahasa gameplay utama.

3. **Chase camera**
   Camera berada di belakang pesawat, sedikit di atas, mengikuti roll/strafe player dengan lag halus.

4. **Cinematic storm battlefield**
   Arena harus punya cloud depth, ocean/city warzone, smoke columns, debris, distant air traffic, explosions, dan boss set-piece di depan.

5. **Weather as tactical puzzle**
   Wind, cloud, rain, lightning, storm cell, dan visibility mempengaruhi aim, dodge, loadout, dan route/corridor choice.

6. **Readable VFX**
   Player fire biru/cyan, enemy fire merah/oranye, weather biru-putih/abu, explosion kuning/oranye. Efek boleh intens, tetapi dodge zone harus tetap terbaca.

7. **No legacy setup in final**
   Tidak ada car/convoy prologue, tidak ada top-down fallback, tidak ada static aircraft photo di gameplay.

## Milestone Produksi

### M0 — Redesign Lock & Repo Cleanup

- [x] Visual target reference committed: `gameplay_visual_lock_build.jpg`.
- [x] Dokumen direction lama diganti ke forward 3D air-combat.
- [x] Repo cleanup audit dibuat: `docs/REPO_CLEANUP_AUDIT.md`.
- [x] Third-person camera/gameplay redesign dibuat: `docs/THIRD_PERSON_AIR_COMBAT_REDESIGN.md`.
- [x] Legacy helper/server/generator lama dihapus dari `tools/` sehingga tidak ada generator convoy/car/top-down yang dipakai ulang.
- [ ] Hapus legacy code/path setelah ForwardAirScene3D playable.

### M1 — ForwardAirScene3D Foundation

- [ ] Buat scene/root system baru untuk forward 3D air combat.
- [ ] Buat camera rig chase: behind/slightly above, look-ahead target, FOV config, camera lag.
- [ ] Tentukan world direction: forward = `-Z`.
- [ ] Player corridor movement: strafe X, altitude Y, boost/brake ringan, roll animation.
- [ ] Port input mobile/keyboard ke movement 3D.
- [ ] Matikan top-down `_draw()` sebagai visual utama gameplay.

### M2 — Player Aircraft GLB

- [ ] Generate/import `assets/models/player_stormhawk.glb`.
- [ ] Tambah hardpoints: nose gun, left/right wing cannon, missile sockets, engine sockets.
- [ ] Material: metal dark, cyan emissive strips, cockpit canopy.
- [ ] Roll/tilt animation berdasarkan input.
- [ ] Engine exhaust 3D: flame core, glow, vapor trail.
- [ ] Collision/hitbox proxy yang readable untuk mobile.

### M3 — Forward Arena Director

- [ ] Spawn storm cloud chunks ahead and move them past camera/player.
- [ ] Add ocean/city warzone layer below with fires/smoke columns.
- [ ] Add distant battle traffic: ally jets, enemy silhouettes, tracer lines.
- [ ] Add weather volumes: rain sheets, cloud concealment, lightning flashes.
- [ ] Add debris/near-camera streaks for speed feel.
- [ ] Ensure no static photo arena is used as gameplay world.

### M4 — 3D Weapon VFX

- [ ] Main cannon cyan stream from aircraft hardpoints.
- [ ] Wing cannon thick bolts with longer trail.
- [ ] Micro missile model/trail from wing sockets.
- [ ] Overcharge lightning laser with impact flare.
- [ ] Enemy red/orange bullets as 3D/projected trails.
- [ ] Hit spark, debris, smoke, and damage flash on enemy models.
- [ ] Camera shake/FOV kick tied to weapon intensity.

### M5 — Enemy/Boss GLB Combat

- [ ] Generate/import enemy fighter/drone/gunship GLB placeholders.
- [ ] Spawn enemies in forward corridor, not 2D top screen.
- [ ] Add readable attack patterns in 3D lanes.
- [ ] Generate/import boss dreadnought GLB placeholder.
- [ ] Add boss weakpoints, turret hardpoints, central cannon charge.
- [ ] Add phase transitions and final multi-stage explosion.

### M6 — UI/UX Refit for Forward Flight

- [ ] HUD reticle/crosshair centered ahead.
- [ ] Lock-on marker and target brackets.
- [ ] Boss bar top-center.
- [ ] HP/shield top-left; score/combo top-right.
- [ ] Ability buttons thumb-safe lower left/right.
- [ ] Radar/weather mini-map bottom-right.
- [ ] Mobile safe-area and touch target pass.

### M7 — Legacy Removal & Repo Slimming

- [ ] Remove convoy/car prologue code from `scripts/main.gd` or replace with new script layout.
- [ ] Remove old convoy/car assets after no runtime references remain.
- [ ] Remove top-down PNG gameplay dependency for player/enemy/boss.
- [ ] Replace save key/migration away from `storm_convoy` naming.
- [ ] Rebuild root Web export.
- [ ] Run Godot check/import/export + browser QA.
- [ ] Grep docs/code for forbidden legacy strings.

### M8 — Content Expansion

- [ ] 3+ forward air arenas: Storm Ocean, Burning Delta, Thunder Ridge.
- [ ] 4+ player aircraft GLB variants.
- [ ] 6+ enemy GLB types.
- [ ] 3+ boss set-pieces.
- [ ] Weather-specific mission modifiers and loadout decisions.
- [ ] Audio, haptics-like screen pulse, cinematic transitions.

## Acceptance Criteria v0.5 Forward Slice

Before calling the next playable build acceptable:

- Browser starts in 9:16 and shows Godot canvas.
- Player aircraft is a GLB model visible from behind/slightly above.
- Camera follows behind with forward look-ahead.
- Game motion is forward into 3D depth.
- At least one 3D enemy wave appears ahead.
- Player weapon VFX emits from 3D hardpoints and reads stronger than thin bullets.
- Arena includes moving cloud/warzone layers, not static background photo.
- No car/convoy prologue appears in the flow.
- No top-down gameplay camera is used as the main gameplay mode.
- Root Web export still outputs `index.html`, `index.js`, `index.wasm`, `index.pck`.
