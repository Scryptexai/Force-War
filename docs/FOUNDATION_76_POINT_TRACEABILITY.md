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
| A | Shot player harus mengarah ke depan/depth, bukan ke atas/vertical screen | STARTER | Screenshot 9:16 memperlihatkan shot keluar dari pesawat menuju horizon/boss |
| B | Player aircraft memakai GLB source yang valid/original, bukan rebuild low-quality | STARTER | Runtime bridge `playerModelSource`, visual screenshot, audit asset |
| C | Background buruk/code-generated harus dibersihkan sebelum art phase berikutnya | BLOCKER | Screenshot arena lebih clean, asset-backed, tidak penuh clutter |
| D | QA otomatis tidak cukup; screenshot/manual visual gate wajib | PARTIAL | Capture browser disimpan/direview setiap visual claim |
| E | Tidak tambah fitur gameplay besar sebelum A-C stabil | ACTIVE | Commit berikutnya harus fokus correction pass |

## 76-point traceability matrix

| ID | Requirement | Area | Status | Catatan implementasi/gate |
|---:|---|---|---:|---|
| 01 | Force War adalah mobile-first 3D forward-air shooter | Direction | PARTIAL | Mode forward-air aktif, tapi visual foundation masih dikoreksi |
| 02 | Bukan convoy/car/top-down game | Direction | PARTIAL | Runtime launch forward-air; audit legacy tetap diperlukan |
| 03 | Bukan vertical upward/Sky Force camera | Camera | PARTIAL | Camera chase aktif, shot visual harus dikunci agar tidak terbaca vertical |
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
| 19 | Aircraft harus punya muzzle/hardpoint contract | Weapons | STARTER | Starter sockets `MuzzleForward_*` ditambah di rig runtime |
| 20 | Shot harus lahir dari hardpoint aircraft | Weapons | STARTER | Bridge `playerShotFromHardpoint=true`; final Blender sockets pending |
| 21 | Shot arah ke depan/horizon/boss | Weapons | STARTER | Bridge `shotDirectionMode=forward_depth_negative_z`; screenshot gate wajib |
| 22 | Shot tidak boleh terbaca sebagai kolom ke atas | Weapons | STARTER | Billboard projectile dimatikan untuk pool; forward XZ quads dipakai |
| 23 | Projectile visual align dengan logic projectile | Weapons | PARTIAL | Pool logic/visual masih perlu hard sync penuh |
| 24 | Enemy bullets tidak continuous homing/chasing | Combat | PARTIAL | Pattern fixed/scheduled; visual review perlu |
| 25 | Bullet-hell tidak pakai Node3D/physics body per bullet | Performance | VERIFIED | Logical dictionaries + MultiMesh visual pool |
| 26 | Projectile pooling wajib | Performance | VERIFIED | Enemy/player logical pool + visual MultiMesh aktif |
| 27 | Radius collision logical untuk bullet hell | Combat | VERIFIED | `projectileCollisionMode=pooled_logical_radius_no_physics_body` |
| 28 | Data-driven projectile definition | Data | VERIFIED | JSON `data/projectiles` dibaca runtime |
| 29 | Player projectile bisa hit boss secara real logic | Combat | VERIFIED | QA waits `playerProjectileHits > 0` dan HP boss turun |
| 30 | Boss bukan HP dekoratif | Boss | VERIFIED | `BossPhaseController` aktif |
| 31 | Boss punya shield/wings/turrets/core | Boss | VERIFIED | Bridge damage model parts |
| 32 | Boss punya phase transition | Boss | PARTIAL | Phase logic ada; visual phase belum cukup jelas |
| 33 | Boss weakpoint target routing | Boss | PARTIAL | Data/bridge ada; visual target bracket pending |
| 34 | Boss attack pattern scheduler | Boss | VERIFIED | Bridge `bossPatternScheduler=true` |
| 35 | Boss hardpoint/turret visual harus terbaca | Boss | PENDING | Visual pass berikutnya setelah foundation shot/player benar |
| 36 | BattlefieldDirector untuk background war | Arena | PARTIAL | `ForwardArenaDirector` ada; visual quality masih blocker |
| 37 | Background tidak boleh static/acak code-looking | Arena | BLOCKER | Perlu cleanup asset-backed pass |
| 38 | Background harus asset-backed/GLB/photos/textures proper | Arena | PARTIAL | GLB deck/boss ada; clutter procedural perlu audit |
| 39 | No convoy/cars terlihat di aircraft gameplay | Cleanup | PARTIAL | Runtime forward-air; asset legacy masih ada untuk audit |
| 40 | No road/convoy boot/loading visual | Loading | PARTIAL | Sudah pernah diperbaiki; regression check wajib |
| 41 | Loading page branded Force War | UI | PARTIAL | Existing branding ada; visual QA ulang perlu |
| 42 | Loading slideshow background sesuai theme | UI | PARTIAL | Ada assets; belum dievaluasi ulang setelah reset |
| 43 | Logo/wordmark dipakai | UI | PARTIAL | Ada asset/logo; review perlu |
| 44 | HUD mobile harus clear dan tidak messy | UI | PARTIAL | HUD minimal; weakpoint/phase UI pending |
| 45 | No unclear overlay objects in arena | Visual | BLOCKER | Perlu cleanup screenshot pass |
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
| 60 | Screenshot/browser proof before claiming visual success | Process | ACTIVE | Starter requires capture after QA |
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
| 76 | Debug HUD/benchmark scenes for budgets and correctness | QA | PENDING | Browser bridge exists; dedicated benchmark/debug scene pending |

## Phase 1 starter scope now

This starter only addresses the first foundation gates:

1. Runtime player visual source is changed away from the generated `player_stormhawk.glb` and toward the Blender-prepared derivative of the uploaded GLB; the original uploaded GLB remains the source contract.
2. Runtime muzzle hardpoint sockets are introduced as a temporary contract until Blender-authored sockets are exported.
3. Player shot VFX is changed from billboard/vertical screen quads into forward-depth XZ-aligned projectile quads.
4. QA bridge flags are added so this regression cannot silently return.

This is **not** a final visual-quality claim. Background cleanup, original GLB scale/orientation visual approval, and full Blender socket authoring remain blocking follow-up work.
