# Force War — Forward 3D Air Combat Roadmap

Tanggal update: 2026-10-05
Status: roadmap high-level setelah koreksi visual Phase 2 dan instruksi Blender pipeline.

Roadmap ini memakai **phase besar** dengan output browser-verifiable. Detail checklist teknis ada di `docs/REBUILD_ROADMAP_AND_MILESTONES.md`. Pipeline asset/animation baru ada di `docs/BLENDER_ANIMATION_PIPELINE.md`.

---

## Visi Produk

Force War diarahkan menjadi **3D forward air-combat mobile game**:

- kamera chase di belakang dan sedikit di atas pesawat;
- player aircraft, enemy fighter, missile, dan boss harus GLB/3D;
- gameplay bergerak maju ke medan perang 3D, bukan vertical/top-down shooter;
- visual harus sinematik, readable, dan original;
- environment/weather memengaruhi gameplay, bukan sekadar background.

---

## Koreksi Visual Aktif

Arahan terbaru yang harus dipatuhi sebelum lanjut combat package:

1. **Blender wajib masuk pipeline produksi** untuk asset, sockets, dan animation clips.
2. Uploaded hero jet GLB dipakai sebagai enemy placeholder: `assets/models/enemy_hero_jet.glb`.
3. Player aircraft harus lebih kecil di layar mobile agar ruang gerak terlihat lebih luas.
4. Cloud geometry berulang/tebal dihapus dari arena aktif; hanya thin haze/fog yang boleh tampil.
5. Shot/fire animation menjadi prioritas utama:
   - player cyan shots bergerak maju;
   - enemy red/orange shots bergerak ke arah player secara readable;
   - enemy bullets tidak boleh terus-menerus mengejar player.

---

## Status Realistis Saat Ini

| Area | Status | Catatan |
| --- | --- | --- |
| Godot/Web pipeline | 80% | Root export, Vercel flow, server, QA browser berjalan. |
| Forward chase camera | 70% | Arah kamera diterima user, masih perlu polish gameplay feel. |
| Player GLB gameplay | 45% | Player GLB aktif dan diperkecil; model final/Blender sockets belum selesai. |
| Enemy GLB integration | 35% | Uploaded hero jet GLB aktif sebagai placeholder musuh. |
| Shot animation readability | 40% | Cyan player pulses dan red/orange lanes aktif; butuh hardpoint/socket dan hit logic lengkap. |
| Cinematic arena | 40% | Boss anchor, warzone, shots, haze aktif; cloud geometry sudah dimatikan sesuai koreksi. |
| Blender production pipeline | 35% | Blender `bpy 4.5.14 LTS` runtime installed in sandbox and used to generate `enemy_hero_jet_blender_ready.glb`; final boss/player assets still pending. |
| Legacy cleanup | 35% | Gameplay runtime sudah forward-air, tetapi legacy monolith/assets lama masih perlu dipangkas bertahap. |
| Overall menuju full target | ±45% | Baseline playable sudah ada, tetapi belum full combat package/final art. |

---

## Big Phase Roadmap

### Phase 0 — Direction Lock, Audit, Code Map

Status: **Done / pushed**

Output:

- arah forward 3D air-combat dikunci;
- camera benchmark bukan lagi top-down Sky Force, tetapi chase/rail-forward air combat;
- repo/code cleanup map dibuat;
- phase kecil `R#` diganti menjadi phase besar.

---

### Phase 1 — Core Forward Flight Rebuild

Status: **Done / pushed**

Output:

- `ForwardAirScene3D` aktif;
- player GLB aircraft berjalan di corridor X/Y;
- chase camera behind/slightly-above;
- direct launch ke aircraft gameplay tanpa convoy/car prologue;
- browser QA 720×1280.

---

### Phase 2 — Cinematic Arena & Weather Battlefield

Status: **Baseline done, correction pass active**

Sudah ada:

- dreadnought/boss anchor;
- warzone depth;
- red/orange enemy lanes;
- cyan player fire lanes;
- shield/explosion/smoke visual elements;
- weather state bridge.

Koreksi terbaru:

- cloud banks/solid cloud geometry dimatikan;
- hanya thin fog/haze yang dipertahankan;
- player scale diperkecil;
- uploaded enemy hero jet GLB sudah diproses Blender menjadi `enemy_hero_jet_blender_ready.glb` dan dipakai runtime;
- shot animation diperjelas dengan moving pulses, dan enemy placeholder punya Blender-authored attack-pass/muzzle/engine animation clip.

Acceptance Phase 2 setelah koreksi:

- gameplay tetap 9:16 dan browser-verifiable;
- player tidak memenuhi layar bawah;
- tidak ada cloud bank berulang yang menutup arena;
- boss/projectile lanes terbaca;
- visual bridge menyatakan `cloudGeometry=false`, `enemyHeroJetModel=true`, `enemyHeroJetSource=blender_ready_glb`, `enemyHeroJetAnimation=EnemyJet_AttackPass_Loop`, dan `shotAnimation=player_cyan_pulses_enemy_red_lanes`.

---

### Phase 3 — Weapon, Enemy, Boss Combat Package

Status: **Active next production phase**

Scope besar:

1. **Blender asset/animation lane**
   - Blender pipeline sudah dijalankan via official `bpy 4.5.14 LTS` runtime untuk enemy placeholder; gunakan executable Blender penuh ketika environment menyediakan binary;
   - normalize enemy/player/boss GLB;
   - add hardpoint sockets: muzzle, missile, engine, hit core;
   - export Godot-ready GLB with animation clips.

2. **Weapon systems**
   - nose cannon, wing cannon, missile salvo, laser/burst overcharge;
   - cyan player projectiles must animate from actual aircraft hardpoints;
   - wind/weather affects bullet drift but does not make effects unreadable.

3. **Enemy systems**
   - enemy hero jet placeholder waves;
   - readable attack lanes;
   - no permanent homing/chasing enemy bullet behavior;
   - hit sparks, smoke, debris, damage feedback.

4. **Boss package**
   - dreadnought attack phases;
   - boss weak points;
   - boss lasers and missile barrages;
   - later replace procedural boss anchor with Blender-authored GLB.

Acceptance:

- player shots visibly spawn/move from aircraft;
- enemy shots move in red/orange readable lanes;
- enemy hero jet GLB appears as combat placeholder;
- boss is fightable, not only visual;
- QA and browser preview pass.

---

### Phase 4 — Weather Loadout Strategy & Mission Structure

Status: **Planned**

Scope:

- pre-stage weather forecast screen;
- loadout selection based on wind/rain/lightning/fog;
- weather-driven route/corridor choices;
- stage scoring and replay loop;
- mobile tuning.

Acceptance:

- forecast affects loadout decision;
- weather changes weapon/movement behavior;
- each mission has a clear tactical puzzle.

---

### Phase 5 — Full Visual Production & Optimization

Status: **Planned**

Scope:

- replace placeholders with Blender-authored final aircraft/enemies/boss;
- LOD and texture budget for Web/mobile;
- animation polish, hit reactions, camera shake, audio hooks;
- cleanup legacy convoy/top-down code paths.

Acceptance:

- no static aircraft photo/sprite in gameplay;
- no car/convoy game flow at launch;
- stable root Web export and Vercel deployment;
- full visual package stays readable at 720×1280.
