# Force War — UI/UX Research for Forward 3D Air Combat

Tanggal redesign lock: 2026-10-05

## 1. Prinsip Baru

### 1.1 Thumb-first, but center-readable

Game tetap 9:16 mobile. Jempol harus bisa mengontrol movement dan ability, tetapi area tengah layar harus bersih untuk reticle, incoming fire, dan target depth.

### 1.2 Reticle-first readability

Karena game tidak lagi top-down, player perlu:

- center reticle;
- lock-on bracket;
- missile warning;
- target distance/depth cues;
- boss weakpoint indicators.

### 1.3 Aircraft-only progression

Tidak ada garage car. Semua progression diarahkan ke aircraft:

- aircraft unlocks;
- weapon hardpoint upgrades;
- engine/handling;
- storm/weather systems;
- defensive shield/armor.

### 1.4 Weather forecast matters

Forecast bukan text dekorasi. UX harus menunjukkan:

- wind direction/intensity;
- cloud concealment risk;
- rain visibility;
- lightning overcharge chance;
- recommended loadout.

## 2. ATM — Amati, Tiru, Modifikasi

ATM tetap dipakai sebagai metode desain, bukan menyalin aset/IP.

### Amati

- Modern mobile shooters: UI ringkas, upgrade loop jelas, feedback cepat.
- Sky Force-style polish: strong progression, readable effects, massive bosses, beautiful environments.
- Forward rail/chase shooters: center reticle, behind-camera movement, target brackets, boss set pieces.

### Tiru

Yang ditiru hanya pola desain:

- boss bar jelas;
- HP/shield readable;
- ability buttons thumb-safe;
- score/combo satisfying;
- lock-on/reticle in center;
- upgrade categories simple.

### Modifikasi

Force War identity:

- storm/weather forecast decides loadout;
- aircraft GLB visible in gameplay and hangar;
- weather overcharge/shield systems;
- forward storm corridor choices;
- cinematic dreadnought assaults.

## 3. Recommended HUD Components

| Component | Purpose | Placement |
| --- | --- | --- |
| HP/Shield | survivability | top-left |
| Boss HP | objective clarity | top-center |
| Score/Combo | reward feedback | top-right |
| Reticle | aiming center | center |
| Lock-on ring | missile/target acquisition | around enemy/reticle |
| Weather alert | storm hazard | near top/side, not center clutter |
| Ability buttons | missile/shield/storm burst/laser | lower left/right |
| Radar/weather map | spatial threat | bottom-right |

## 4. Mobile Control Recommendation

Default:

- drag anywhere in lower/mid screen to steer aircraft within corridor;
- auto-fire main cannon;
- tap missile button for lock-on/missile salvo;
- tap shield button for emergency defense;
- tap storm burst/overcharge button when charged;
- optional double-tap/gesture for barrel roll or boost.

Keyboard/dev:

- WASD/Arrow = strafe/altitude;
- Shift = boost;
- Space/Enter = confirm/launch;
- 1/2/3/4 = abilities;
- P/Esc = pause/back.

## 5. UX Anti-Patterns to Avoid

- Too many buttons around the aircraft body.
- UI covering center reticle.
- Red enemy bullets blending into orange explosions without outline/glow distinction.
- Player cyan shots so bright they hide enemy warnings.
- Loading/menu art showing cars/convoy while game is aircraft-only.
- Upgrade menus that still mention car stats.

## 6. Next Research Output Needed

Before final implementation polish:

- create HUD wireframe image for 720x1280;
- create hangar wireframe with GLB aircraft preview;
- create weather forecast card layout;
- create ability icon set for missile/shield/storm/laser;
- define safe-area margins for mobile browser/notch.
