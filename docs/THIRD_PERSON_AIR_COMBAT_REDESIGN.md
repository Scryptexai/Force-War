# Force War — Third-Person Forward Air Combat Redesign

Tanggal redesign lock: 2026-10-05

Dokumen ini mengganti arah lama `vertical/top-down Sky Force War` menjadi **3D forward air-combat**. Implementasi gameplay belum dilakukan di pass ini; dokumen ini adalah peta desain supaya pass coding berikutnya tidak membawa setup lama.

## 1. Target Utama

Force War harus terasa seperti player menerbangkan jet 3D maju ke medan perang, bukan ikon pesawat 2D yang naik di canvas.

Target kamera:

```text
camera = chase camera, behind player, slightly above
player = foreground lower-middle, full GLB visible
movement = forward into Z-depth / corridor, not upward screen scroll
combat = enemies, missiles, lasers, boss, terrain chunks exist in 3D world ahead
```

## 2. Benchmark Arah Kamera dan Gameplay

Benchmark bukan untuk menyalin IP/aset, tetapi untuk memahami bahasa kamera/gameplay:

- **Sky Force / modern mobile shmup**: standar visual yang perlu dikejar adalah ledakan besar, laser, boss masif, environment indah, dan efek intens. Official Steam Sky Force Reloaded menekankan gorgeous visuals, meaty explosions, incinerating lasers, colossal bosses, diverse aircraft, beautiful environments, intense effects, progression, dan collectibles.
  Referensi: https://store.steampowered.com/app/667600/Sky_Force_Reloaded/
- **Star Fox 64-style corridor shooter**: benchmark untuk kamera behind-view/rail-forward; pesawat bergerak maju melalui level, menghindari obstacle, menembak musuh di depan, dan boss fight muncul di jalur.
  Referensi: https://www.mobygames.com/game/3536/star-fox-64/
- **Panzer Dragoon-style rail shooter**: benchmark world 3D sinematik, path predetermined, aiming reticle, lock-on, musuh dari berbagai arah, dan level dengan boss event.
  Referensi: https://en.wikipedia.org/wiki/Panzer_Dragoon

Force War harus mengambil prinsip desain, bukan menyalin aset:

```text
Sky Force = visual density, effects, massive boss, mobile polish
Star Fox = behind camera, forward corridor, dodge/boost/laser language
Panzer Dragoon = cinematic rail path, lock-on/readable target priority
Force War = storm-war forward air assault with weather puzzle systems
```

## 3. Perubahan Fundamental dari Build Lama

| Area | Build lama | Target baru |
| --- | --- | --- |
| View | Top-down/vertical canvas | Third-person 3D chase camera |
| Movement | Screen scroll ke atas | Jet maju ke depan di world 3D |
| Player aircraft | PNG/static draw/canvas | GLB 3D aircraft with afterburner and hardpoints |
| Enemy aircraft | 2D sprite/procedural | GLB drones/fighters/gunships with 3D projectiles |
| Boss | 2D/top overlay or simple arena anchor | 3D dreadnought/air fortress ahead of player |
| Arena | Vertical background/tile scroll | Forward storm corridor with clouds, ocean/city, debris, traffic |
| Projectile | 2D bullets drawn on canvas | 3D trails/beams/missiles projected through chase camera |
| Camera FX | Minimal shake | Chase lag, FOV kick, roll influence, cinematic shake |
| Legacy car/convoy | Removed/direct mode but still present in code/docs | Must be fully deleted from gameplay direction |

## 4. Camera Model

### 4.1 Coordinate rule

Rekomendasi Godot 3D convention untuk pass berikutnya:

```text
Forward path direction: -Z
Player corridor center: Vector3(0, 2.0, current_z)
Camera position: player + Vector3(0, 3.2, 8.0)
Camera looks at: player + Vector3(0, 1.0, -18.0)
```

Makna visual:

- Camera berada di belakang jet.
- Camera sedikit lebih tinggi dari jet.
- Nose pesawat mengarah ke depan/atas frame.
- Boss dan target berada di depth depan, bukan di koordinat 2D y atas.

### 4.2 Framing mobile 9:16

Player harus berada di area bawah 25–35% layar, bukan terlalu kecil.

```text
Top 0–20%     = boss bar / sky / distant target
20–55%        = enemy waves, boss weak points, incoming missiles
55–75%        = bullet lanes / dodge zone
75–92%        = player jet GLB, engine trail, ability buttons around safe area
92–100%       = minimal UI/safe area
```

### 4.3 Camera feel

- **Chase lag**: kamera tidak kaku; sedikit terlambat mengikuti strafe player.
- **Roll influence**: saat player bergerak kiri/kanan, pesawat roll 8–18 derajat dan camera ikut sangat halus.
- **FOV kick**: boost/overcharge menaikkan FOV sedikit, lalu kembali normal.
- **Shake layers**:
  - small hit: micro shake.
  - missile/explosion near camera: directional shake.
  - boss cannon: low-frequency rumble.
- **No top-down fallback**: pass coding berikutnya tidak boleh memakai `_draw()` 2D sebagai visual utama gameplay.

## 5. Player Aircraft GLB Requirement

Player tidak boleh lagi foto/PNG statis. Target asset:

```text
assets/models/player_stormhawk.glb
assets/models/player_thunder_warden.glb
assets/models/player_razorwing.glb
assets/models/player_aegis_medic.glb
```

Minimal GLB player harus punya:

- fuselage, cockpit canopy, wings, tail fins;
- weapon hardpoints kiri/kanan;
- engine exhaust sockets;
- material metal gelap + cyan emissive strips;
- optional animation/transform untuk roll/tilt;
- collision proxy sederhana.

Jika belum ada GLB final, boleh pakai procedural placeholder GLB sementara, tetapi tetap bentuk 3D nyata, bukan PNG billboard.

## 6. Forward Arena Requirement

Arena harus berupa world 3D yang bergerak maju. Dua pilihan teknis:

### Opsi A — Player benar-benar bergerak maju

- Player/root bergerak sepanjang `-Z`.
- Arena chunks spawn di depan dan despawn di belakang.
- Camera follow player.

Kelebihan: lebih natural untuk 3D.
Risiko: floating origin perlu dipikirkan untuk long stage.

### Opsi B — Player relatif diam, world chunks bergerak ke kamera

- Player tetap sekitar origin.
- Semua environment chunks bergerak dari depan ke belakang.
- Camera tetap chase tapi world memberi ilusi forward motion.

Kelebihan: lebih mudah untuk Web/mobile dan long stage.
Risiko: harus disiplin agar tidak terasa seperti top-down scroll ulang.

Rekomendasi awal: **Opsi B** untuk vertical slice, lalu upgrade ke Opsi A jika stage panjang butuh navigasi world lebih bebas.

## 7. Arena Layer Stack

Target scene graph:

```text
ForwardAirScene3D
  WorldEnvironment / storm color grading
  DirectionalLight3D + lightning flash lights
  CameraRig3D
    Camera3D
  PlayerRig3D
    PlayerAircraftGLB
    EngineExhaustNodes
    WeaponHardpointNodes
  ForwardArenaDirector
    FarStormCloudChunks
    MidCloudBanks
    OceanCityWarzoneChunks
    SmokeColumns
    DebrisField
    DistantBattleTraffic
  EnemyDirector3D
    FighterGLB / DroneGLB / GunshipGLB
    Missile3D / BulletTrail3D / LaserBeam3D
  BossDirector3D
    DreadnoughtGLB
    Turrets / Weakpoints / CentralCannon
  HUDCanvasLayer
```

## 8. Weapon VFX Target

### Player identity

- Main weapon: cyan/blue energy stream with white core.
- Wing cannon: thicker bolts from wing hardpoints.
- Missile: physical rocket/flare with smoke trail.
- Overcharge: lightning laser beam from nose/weapon spine.
- Shield: blue hex/electric bubble around player GLB.
- Engine: constant afterburner flames and vapor trails.

### Enemy identity

- Bullets: red/orange plasma with short trails.
- Boss cannon: orange/red charge core, warning reticle, beam sweep.
- Missiles: smoke trails + red warning marker.
- Explosions: orange/yellow core, smoke debris, shock ring.

### Readability rule

```text
Player = cyan/blue/white
Enemy = red/orange
Weather = blue-white lightning, grey rain/fog, cyan wind streaks
Explosion/environment fire = orange/yellow/smoke
```

## 9. Boss Set Piece Target

Visual target dari `gameplay_visual_lock_build.jpg`:

```text
Boss/Dreadnought occupies upper-middle depth,
not a static image at top of screen.
```

Boss should include:

- GLB carrier/dreadnought hull;
- central glowing weather cannon;
- separate turret hardpoints;
- weakpoint lights;
- engine glow and smoke damage states;
- phase transitions: shields, exposed core, missile barrage, laser sweep;
- final multi-stage explosion.

## 10. Weather as 3D Gameplay

| Weather | 3D forward implementation |
| --- | --- |
| Wind | offsets projectile trails, pushes smoke/rain sheets, creates turbulence shake |
| Rain | screen/world streaks, lower visibility, wet reflections on aircraft/arena |
| Clouds | volumetric-ish GLB/particles that hide drones until close/radar active |
| Lightning | overcharge player, strike rods/turrets, flash scene lighting |
| Storm cell | moving hazard volume in corridor forcing lane/altitude choice |

## 11. First Implementation Slice Setelah Dokumen

Urutan coding yang benar nanti:

1. Remove direct dependency on top-down `_draw()` for gameplay world.
2. Create `ForwardAirScene3D` and chase camera rig.
3. Generate/import placeholder GLB player aircraft.
4. Spawn player GLB in chase camera with afterburner.
5. Convert corridor movement from 2D y-scroll to 3D local X/Y within forward corridor.
6. Add forward arena chunks: clouds + ocean/city warzone below.
7. Add one GLB enemy wave and one 3D projectile type.
8. Add 3D VFX weapon stack.
9. Add boss dreadnought GLB placeholder/set-piece.
10. Remove legacy car/convoy/top-down code/assets after replacement is verified.

## 12. Acceptance Gate

A build is accepted only if:

- Browser shows a real GLB player aircraft, not a static photo/PNG.
- Camera is behind and slightly above the aircraft.
- The game reads as moving forward into depth.
- Arena has at least 4 moving 3D/depth layers.
- Player weapon effects are emitted from model hardpoints.
- Boss/enemy exists ahead in 3D space.
- No convoy/car/top-down gameplay appears in the player-facing flow.
