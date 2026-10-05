# Force War — Forward Air Combat VFX Research

Tanggal redesign lock: 2026-10-05

Tujuan dokumen ini adalah memetakan efek yang dibutuhkan untuk gameplay **3D forward chase camera**, bukan lagi top-down 2D/canvas bullets.

## 1. Benchmark Ringkas

### Sky Force-style visual intensity

Sky Force Reloaded secara official diposisikan sebagai shoot'em up modern dengan gorgeous visuals, meaty/flashy explosions, incinerating lasers, colossal bosses, diverse aircraft, beautiful environments, intense effects, progression, and collectibles. Prinsip yang diambil untuk Force War:

- ledakan harus terasa berat/layered;
- laser harus tebal, terang, dan punya impact flare;
- boss harus massive dan multi-phase;
- environment harus indah/hidup, bukan latar mati;
- efek intens tetapi tetap readable.

Reference: https://store.steampowered.com/app/667600/Sky_Force_Reloaded/

### Forward rail/chase shooter readability

Star Fox/Panzer Dragoon-style language memberi pelajaran untuk forward camera:

- reticle/target marker penting karena target berada di depth;
- projectile harus punya trail agar arah terbaca;
- enemies can approach from forward/sides but camera must preserve dodge readability;
- lock-on/charged attack memperkuat feel 3D.

References:

- https://www.mobygames.com/game/3536/star-fox-64/
- https://en.wikipedia.org/wiki/Panzer_Dragoon

## 2. VFX Problem di Build Lama

Build lama sudah menambah jumlah peluru, tetapi masih terasa kurang karena:

- projectile masih dibaca sebagai garis/canvas kecil;
- efek tidak keluar dari hardpoint model 3D;
- kamera tidak memberi speed/impact karena masih top-down/overlay;
- hit impact kurang kuat;
- engine exhaust player belum menjadi identitas visual permanen;
- arena belum memberi smoke/debris/near-miss layer yang membuat perang terasa hidup.

## 3. New VFX Pillars

### 3.1 Hardpoint-based weapon emission

Setiap tembakan harus lahir dari titik fisik pada GLB:

```text
NoseGunSocket
LeftWingCannonSocket
RightWingCannonSocket
LeftMissileSocket
RightMissileSocket
EngineLeftSocket
EngineRightSocket
```

Tanpa ini, efek akan terasa melayang seperti canvas overlay.

### 3.2 Persistent player identity

Player harus selalu punya VFX signature:

- afterburner flame biru/orange;
- vapor trail putih/cyan dari sayap;
- cyan emissive strips di body;
- muzzle glow saat auto-fire;
- slight shield shimmer saat invulnerable.

### 3.3 Color ownership

| Source | Color language |
| --- | --- |
| Player main cannon | cyan core + white center + blue glow |
| Player wing cannon | thick cyan/white bolt, lower rate, stronger trail |
| Player missile | orange flame + grey smoke + cyan lock marker |
| Overcharge | blue-white lightning beam + arc branches |
| Enemy bullet | red/orange plasma |
| Boss cannon | red/orange charge core + warning ring |
| Explosion | yellow/orange core + black smoke/debris |
| Shield | electric blue/hex grid |
| Weather | blue-white lightning, grey rain/fog, cyan wind streaks |

## 4. Player Weapon VFX Stack

### 4.1 Main Cannon Stream

Target look:

- rapid cyan bolts or continuous pulsed stream;
- white core, cyan glow, tapered trail;
- slight spread but converges toward reticle/target;
- appears dense even at low upgrade.

Implementation target:

```text
3D projectile trail or beam segment
emitted every fire tick from nose/inner wing sockets
short lifetime but long enough to create stream continuity
```

### 4.2 Wing Cannon

Target look:

- less frequent but larger bolts;
- emitted from outer wing hardpoints;
- leaves stronger glow/trail;
- penetrates or hits hard targets with visible spark.

### 4.3 Micro Missiles

Target look:

- small physical missile/flare;
- smoke trail curves slightly;
- launch flash from wing socket;
- lock-on marker before launch if target is acquired.

### 4.4 Overcharge Lightning Laser

Target look:

- thick blue-white beam forward;
- electric arcs around beam;
- beam impact flare on boss/enemy surface;
- brief FOV kick and screen rumble.

### 4.5 Shield Bubble

Target look:

- transparent blue bubble around player GLB;
- hex arcs/scan rings;
- shimmer when hit;
- no full-screen clutter.

### 4.6 Engine Exhaust

Target look:

- always visible when flying;
- expands during boost/overcharge;
- leaves short vapor/heat streak behind;
- helps sell forward motion.

## 5. Enemy and Boss VFX Stack

### 5.1 Enemy bullets

- red/orange 3D plasma dots with short trails;
- pattern lanes are readable in chase camera;
- no constant unfair homing;
- near misses can flash at screen edge.

### 5.2 Boss cannon charge

Sequence:

1. Core glow increases.
2. Warning ring/line appears on player dodge lane.
3. Audio/visual pulse.
4. Beam fires with recoil flash.
5. Smoke/heat remains briefly at cannon mouth.

### 5.3 Missile barrage

- physical missile streaks from boss pods;
- smoke trails create battlefield density;
- target warnings give dodge time;
- explosion on miss/hit creates smoke puffs.

### 5.4 Damage state

Boss must show damage before death:

- turret sparks;
- panels catch fire;
- smoke columns from hull;
- weakpoint exposed glow;
- final explosion chain from multiple points.

## 6. Arena VFX Stack

### 6.1 Clouds

- Far cloud layers move slowly.
- Mid cloud banks pass near camera.
- Cloud occlusion hides/reveals enemies.
- Lightning lights cloud edges.

### 6.2 Warzone below

- Ocean/city chunk scrolls under the player in perspective.
- Fire/smoke columns rise.
- Distant ship/building explosions trigger occasionally.
- Tracer lines cross far background.

### 6.3 Rain and wind

- Rain streaks follow camera velocity and wind vector.
- Wind bends smoke/trails.
- Storm gust causes camera/player turbulence.

### 6.4 Debris/near-camera speed lines

- Small debris streaks pass sides of camera.
- Use sparingly to avoid motion sickness.
- Helps sell forward speed without making arena too fast.

## 7. Camera Coupling

Every major VFX should influence camera subtly:

| Event | Camera response |
| --- | --- |
| main cannon | micro vibration only if strong upgrade |
| wing cannon | tiny directional kick |
| missile launch | brief local shake + smoke burst |
| overcharge laser | FOV +2 to +4 degrees, low rumble |
| enemy hit player | short impact shake |
| boss cannon | warning rumble before shot |
| large explosion | directional shake based on screen/depth proximity |

## 8. Acceptance Checklist

VFX pass dianggap benar jika:

- player fire looks strong even when paused in screenshot;
- projectile trails are readable in depth;
- shots originate from GLB hardpoints;
- engine exhaust is always visible;
- hits create sparks/debris/smoke;
- enemy/boss shots are red/orange and readable;
- arena has living smoke/cloud/fire/weather effects;
- visual density approaches `gameplay_visual_lock_build.jpg` without hiding the dodge zone.
