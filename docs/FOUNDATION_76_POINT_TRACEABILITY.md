# Force War — 76-Point Foundation Traceability

Tanggal: 2026-10-06  
Branch kerja: `arena/01a100ae-force-war`  
Godot target: **4.6.2 stable** sampai ada approval eksplisit untuk migrasi.

Dokumen ini dibuat sebagai gate koreksi setelah feedback bahwa fondasi visual/gameplay masih salah: shot terbaca ke atas, player aircraft tidak boleh menjadi remake low-quality dari GLB user, dan background masih belum layak jadi fondasi phase berikutnya.

Status yang dipakai:

- `BLOCKER`: tidak boleh lanjut phase berikutnya sebelum benar.
- `STARTER`: koreksi awal sudah dimulai, masih perlu bukti screenshot/manual review.
- `PARTIAL`: sudah ada sebagian, belum final.
- `PENDING`: belum dikerjakan.
- `VERIFIED`: sudah dibuktikan oleh code + QA + screenshot/manual gate.

## Foundation blockers sebelum lanjut fitur baru

| Gate | Requirement | Status | Bukti wajib |
|---|---|---:|---|
| A | Shot player harus mengarah ke depan/depth, bukan ke atas/vertical screen | PARTIAL | Runtime lock `shotDirectionMode=forward_depth_negative_z`; screenshot tetap wajib untuk visual approval |
| B | Player aircraft memakai GLB source yang valid/original, bukan rebuild low-quality | PARTIAL | Runtime player memakai Blender-prepared derivative dari uploaded GLB; original source path tetap dilacak |
| C | Background buruk/code-generated harus dibersihkan sebelum art phase berikutnya | STARTER | Foundation clean mode mengurangi vertical beams/explosions/shield clutter; masih butuh full art pass |
| D | QA otomatis tidak cukup; screenshot/manual visual gate wajib | VERIFIED | Phase 3 debug gate saves browser screenshot/state proof and manual capture was inspected |
| E | Tidak tambah fitur gameplay besar sebelum A-C stabil | ACTIVE | Commit berikutnya harus fokus correction pass |

## 76-point traceability matrix

| ID | Requirement | Area | Status | Catatan implementasi/gate |
|---:|---|---|---:|---|
| 01 | Force War adalah mobile-first 3D forward-air shooter | Direction | PARTIAL | Mode forward-air aktif, tapi visual foundation masih dikoreksi |
| 02 | Bukan convoy/car/top-down game | Direction | PARTIAL | Runtime launch forward-air; audit legacy tetap diperlukan |
| 03 | Bukan vertical upward/Sky Force camera | Camera | VERIFIED | QA locks `cameraMode=chase_behind_above`, forward shot direction, and no vertical shot columns |
| 04 | Camera di belakang dan sedikit di atas aircraft | Camera | PARTIAL | Bridge `cameraMode=chase_behind_above`; screenshot gate tetap wajib |
| 05 | Gameplay bergerak ke depan/depth scene | Gameplay | PARTIAL | Forward progress aktif; projectile visual sedang dikoreksi ke -Z |
| 06 | Game resolution 9:16 | Mobile | VERIFIED | QA browser assert 720x1280 |
| 07 | Android/mobile adalah production truth | Platform | PENDING | Web masih debug; Android belum export/profile |
| 08 | Web/Vercel hanya preview/debug | Platform | PARTIAL | Server root preview aktif |
| 09 | Satu gameplay codebase, bukan fork Android/Web | Architecture | PARTIAL | Renderer-aware flags mulai ada; abstraction belum final |
| 10 | Godot 4.6.2 stable dipakai sampai ada approval upgrade | Toolchain | VERIFIED | Export/check memakai 4.6.2 |
| 11 | Jangan silent upgrade ke 4.7.2 | Toolchain | VERIFIED | Migrasi harus terpisah dengan approval |
| 12 | GDScript sebagai runtime gameplay utama | Toolchain | VERIFIED | Script runtime GDScript |
| 13 | Blender 4.5 LTS/bpy pipeline untuk asset/animasi | Asset | PARTIAL | bpy pipeline ada; source `.blend` final belum lengkap |
| 14 | `.blend` sebagai source contract jangka panjang | Asset | PENDING | Masih perlu source authoring final |
| 15 | `.glb` sebagai delivery contract ke Godot | Asset | PARTIAL | GLB aktif; provenance perlu dirapikan |
| 16 | Player aircraft harus GLB 3D, bukan sprite/foto | Asset | STARTER | Runtime diarahkan ke Blender-prepared derivative dari uploaded GLB source |
| 17 | Player GLB user tidak boleh dibongkar/remade jadi visual buruk | Asset | STARTER | Starter memakai `enemy_hero_jet_blender_ready.glb` sebagai derivative runtime dari original `enemy_hero_jet.glb`; perlu visual review |
| 18 | Scaling player harus mobile-readable | Mobile | PARTIAL | Scale dikoreksi; perlu screenshot review |
| 19 | Aircraft harus punya muzzle/hardpoint contract | Weapons | PARTIAL | Tahap 2 binds actual GLB sockets `Muzzle_Left`/`Muzzle_Right`; fallback sockets remain only as safety |
| 20 | Shot harus lahir dari hardpoint aircraft | Weapons | VERIFIED | Phase 2/3 QA locks visual and logical player shots to `glb_socket_runtime` / `glb_muzzle_socket`; near-camera legacy pulse nodes are disabled |
| 21 | Shot arah ke depan/horizon/boss | Weapons | VERIFIED | QA locks `shotDirectionMode=forward_depth_negative_z`, `playerMuzzleForwardZLocked=true`, and phase screenshots confirm depth fire |
| 22 | Shot tidak boleh terbaca sebagai kolom ke atas | Weapons | VERIFIED | Phase 3 QA locks forward XZ projectiles plus `rainGeometryMode=haze_only_no_vertical_columns` / `nearRainSheetCount=0` |
| 23 | Projectile visual align dengan logic projectile | Weapons | PARTIAL | Pool logic/visual masih perlu hard sync penuh |
| 24 | Enemy bullets tidak continuous homing/chasing | Combat | VERIFIED | Phase 3 QA locks `bossProjectileTracking=false` and `bossProjectileAimingModel=non_homing_forward_depth_lanes` |
| 25 | Bullet-hell tidak pakai Node3D/physics body per bullet | Performance | VERIFIED | Logical dictionaries + MultiMesh visual pool |
| 26 | Projectile pooling wajib | Performance | VERIFIED | Enemy/player logical pool + visual MultiMesh aktif |
| 27 | Radius collision logical untuk bullet hell | Combat | VERIFIED | `projectileCollisionMode=pooled_logical_radius_no_physics_body` |
| 28 | Data-driven projectile definition | Data | VERIFIED | JSON `data/projectiles` dibaca runtime |
| 29 | Player projectile bisa hit boss secara real logic | Combat | VERIFIED | QA waits `playerProjectileHits > 0` dan HP boss turun |
| 30 | Boss bukan HP dekoratif | Boss | VERIFIED | `BossPhaseController` aktif |
| 31 | Boss punya shield/wings/turrets/core | Boss | VERIFIED | Bridge damage model parts |
| 32 | Boss punya phase transition | Boss | VERIFIED | Current Phase 3 QA reaches shield break -> turret break -> `PHASE_3_CORE_EXPOSED` with `bossPhaseTransitionCount>=2` |
| 33 | Boss weakpoint target routing | Boss | VERIFIED | Phase 3 QA verifies target routing `shield -> turrets -> core`, socket-bound reticle, and weakpoint damage events |
| 34 | Boss attack pattern scheduler | Boss | VERIFIED | Bridge `bossPatternScheduler=true` |
| 35 | Boss hardpoint/turret visual harus terbaca | Boss | VERIFIED | Current Phase 3 QA verifies `Boss_Muzzle_Core/Left/Right`, forward socket fire VFX, logical socket spawns, and non-homing boss fire; final destructible turret art remains future polish |
| 36 | BattlefieldDirector untuk background war | Arena | PARTIAL | `ForwardArenaDirector` ada; visual quality masih blocker |
| 37 | Background tidak boleh static/acak code-looking | Arena | STARTER | Clutter visual pass mengurangi beams/explosions/tracers; full background art rebuild masih blocker lanjutan |
| 38 | Background harus asset-backed/GLB/photos/textures proper | Arena | PARTIAL | GLB deck/boss ada; clutter procedural perlu audit |
| 39 | No convoy/cars terlihat di aircraft gameplay | Cleanup | PARTIAL | Runtime forward-air; asset legacy masih ada untuk audit |
| 40 | No road/convoy boot/loading visual | Loading | PARTIAL | Sudah pernah diperbaiki; regression check wajib |
| 41 | Loading page branded Force War | UI | PARTIAL | Existing branding ada; visual QA ulang perlu |
| 42 | Loading slideshow background sesuai theme | UI | PARTIAL | Ada assets; belum dievaluasi ulang setelah reset |
| 43 | Logo/wordmark dipakai | UI | PARTIAL | Ada asset/logo; review perlu |
| 44 | HUD mobile harus clear dan tidak messy | UI | PARTIAL | HUD stays compact and shows boss phase; deeper visual/UI art polish still pending |
| 45 | No unclear overlay objects in arena | Visual | PARTIAL | Phase 3 removes near-camera rain sheets and legacy cyan pulse columns; screenshot gate is cleaner but final arena art pass remains |
| 46 | Clouds tidak boleh muncul continuous | Weather/Visual | PARTIAL | `cloudGeometry=false`; haze/fog masih perlu tuning |
| 47 | Thin fog/haze boleh, continuous clouds tidak | Weather/Visual | PARTIAL | Arena memakai haze/matte; review perlu |
| 48 | Weather harus gameplay, bukan background | Weather | PARTIAL | Wind/rain/lightning affect state; loadout strategy pending |
| 49 | Wind mengubah bullet/player drift | Weather | PARTIAL | Wind drift aktif; perlu tuning setelah shot direction fix |
| 50 | Rain menurunkan visibility | Weather | PARTIAL | `rainVisibility` aktif |
| 51 | Lightning overcharge weapons | Weather | PARTIAL | Overcharge state aktif; visual/weapon balance pending |
| 52 | Cloud/fog hide enemies/visibility gameplay | Weather | PENDING | Cloud geometry disabled; needs haze occlusion design |
| 53 | Forecast sebelum stage | Flow | PARTIAL | Flow ada sebagian; strategic UI belum final |
| 54 | Player memilih loadout berdasarkan forecast | Flow | PARTIAL | Loadout exists; forecast impact needs proof |
| 55 | Environment puzzle/system | Design | PENDING | Hazard lanes/storm cells need clearer gameplay |
| 56 | Originalitas, bukan common Sky Force clone | Design | PARTIAL | Forward rail/cinematic direction; more unique systems pending |
| 57 | Star Fox/Panzer-style forward reference lebih tepat | Design | PARTIAL | Camera/forward mode follows this; combat still needs polish |
| 58 | Roadmap realistis, jangan overclaim 90% | Process | VERIFIED | Docs use partial/blocker status |
| 59 | Phase besar, bukan micro R# | Process | ACTIVE | Current phase is foundation correction pass |
| 60 | Screenshot/browser proof before claiming visual success | Process | VERIFIED | Phase 3 final debug proof stored at `qa/screenshots/phase3_debug_qa_final.png` plus state/summary JSON |
| 61 | Use Chromium Playwright + @sparticuz/chromium for QA | QA | VERIFIED | `qa:forward` / `qa:web` use it |
| 62 | Web export files in repo root | Deploy | VERIFIED | root `index.*` export |
| 63 | Server setup in repo root for Vercel | Deploy | VERIFIED | `server.js`, `package.json` root |
| 64 | No reliance on primitive SVG placeholder visuals | Visual | PARTIAL | Some SVG legacy exists; gameplay GLB/VFX active but cleanup needed |
| 65 | No static photos as aircraft gameplay | Asset | VERIFIED | Aircraft runtime is GLB |
| 66 | Use real photos/sprites/GLB/assets where appropriate | Visual | PARTIAL | VFX sprites/GLB present; background quality still weak |
| 67 | Blender must truly be used, not just claimed | Asset | PARTIAL | bpy-generated outputs exist; next pass needs source/socket proof |
| 68 | Proper animation through Blender | Animation | PENDING | Enemy/boss first clips exist; player hardpoint animation pending |
| 69 | Enemy hero jet GLB as enemy placeholder | Enemy | PARTIAL | Still used in enemy runtime; now also used as player source starter due correction |
| 70 | Enemy waves/formations in depth | Enemy | PARTIAL | Attack jets visual; gameplay wave scheduler pending |
| 71 | Boss setpiece cinematic battlefield | Boss/Arena | PARTIAL | Boss GLB active; phase VFX pending |
| 72 | VFX abstraction renderer-aware | Architecture | PARTIAL | Web-safe MultiMesh path; Android path pending |
| 73 | GPUParticles/flipbooks for future VFX | VFX | PENDING | Current sprites/quads; particle pass pending |
| 74 | LOD/visibility ranges | Performance | PENDING | Not implemented systematically |
| 75 | Dynamic quality/performance budgets | Performance | PENDING | Not implemented |
| 76 | Debug HUD/benchmark scenes for budgets and correctness | QA | PARTIAL | Dedicated `npm run qa:phase3` browser debug harness exists; broader benchmark scene remains future work |

## Phase 1 starter scope now

This starter plus Tahap 1 pass addresses the first foundation gates:

1. Runtime player visual source is changed away from the generated `player_stormhawk.glb` and toward the Blender-prepared derivative of the uploaded GLB; the original uploaded GLB remains the source contract.
2. Runtime muzzle hardpoint sockets are introduced as a temporary contract until Blender-authored sockets are exported.
3. Player shot VFX is changed from billboard/vertical screen quads into forward-depth XZ-aligned projectile quads.
4. QA bridge flags are added so this regression cannot silently return.

This is **not** a final visual-quality claim. Background cleanup, original GLB scale/orientation visual approval, and full Blender socket authoring remain blocking follow-up work.

## Tahap 1 direction/cleanliness pass update

Tahap 1 setelah starter menambahkan runtime alignment `uploaded_glb_local_negative_y_to_world_negative_z`, mematikan fallback afterburner box yang terlihat seperti blok UI, mengurangi vertical boss beams/explosion/shield clutter, dan mengunci `backgroundClutterMode=foundation_clean` di QA. Ini masih bukan final visual-art pass; tujuannya menghentikan regression arah shot/player sebelum background production dibangun ulang.

## Tahap 2 GLB socket binding update

Phase 0 gate is considered complete enough to proceed because the requirement matrix and blockers are now tracked. Tahap 2 starts by binding player shot visuals and logical player projectile spawn to actual named sockets from the Blender-prepared uploaded GLB (`Muzzle_Left`, `Muzzle_Right`, `Engine_Core`) instead of only runtime-estimated hardpoints. QA now fails if `playerWeaponHardpointBinding` is not `glb_socket_runtime`, if `playerShotSpawnOrigin` is not `glb_muzzle_socket`, or if `logicalPlayerShotOrigin` is not `glb_muzzle_socket`.

## Tahap 2 visible socket fire update

The socket-binding foundation now includes a browser-checked visible fire layer, not only data contracts: two muzzle flash quads and two short forward tracer shards are positioned from the GLB `Muzzle_Left`/`Muzzle_Right` sockets every frame. The intent is to make the important shot/fire animation readable from the aircraft while preserving the forward-depth, non-vertical shot rule.

## Tahap 2 muzzle-forward yaw correction

During the visible socket-fire pass, the socket bridge exposed the muzzle center on the camera-side of the player. Tahap 2 corrects the uploaded GLB runtime yaw so the GLB muzzle sockets are actually in front of the aircraft on world negative-Z, then locks this with `playerMuzzleForwardZLocked=true` in browser QA. This prevents the earlier shot-origin fix from becoming a misleading data-only pass.

## Tahap 3 boss weakpoint/hit-feedback update

Tahap 3 now starts with boss gameplay VFX instead of adding unrelated features: the Dreadnought GLB is searched for `Boss_WeakPoint_Core` plus boss muzzle sockets, a clean reticle follows the active weakpoint, and pooled explosion-sprite impacts spawn from real player projectile hit events. Browser QA now fails unless `phase3GameplayVFXPass=boss_weakpoint_hit_feedback`, `bossWeakpointSocketBinding=glb_boss_socket_runtime`, `bossGLBWeakpointSocketFound=true`, and `bossImpactEvents` is greater than zero.

## Tahap 3 boss muzzle hardpoint fire update

Tahap 3 now also binds boss fire to Dreadnought GLB muzzle sockets (`Boss_Muzzle_Left`, `Boss_Muzzle_Core`, `Boss_Muzzle_Right`). The boss fire is deliberately non-homing and forward-lane based, with visible orange socket lanes plus logical projectile spawns reporting `logicalBossProjectileOrigin=glb_boss_muzzle_socket`. Browser QA now fails if the boss muzzle sockets, socket fire VFX, non-homing bridge, or logical socket spawns are missing.

## Tahap 3 destructible boss phase chunk

Tahap 3 now includes a browser-verified destructible boss progression slice: weakpoint damage accelerates shield/turret break, the boss advances from shield phase to turret phase and then `PHASE_3_CORE_EXPOSED`, the reticle target routes `shield -> turrets -> core`, and destroyed-part VFX markers are active. QA now fails unless `phase3BossCombatChunk=destructible_hardpoint_phase_transition`, `bossPhase=3`, `bossPhaseTransitionCount>=2`, `bossDestroyedPartList` contains `shield` and `turrets`, `bossTargetablePart=core`, and the boss fire remains non-homing/socket-bound.
