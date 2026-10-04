# Asset Catalog — Force War: Sky Force War

Asset game sekarang dibagi tiga lapis:

1. `assets/rendered/` — asset PNG yang dipakai langsung oleh top-down aircraft gameplay. Ini adalah visual pass AI-painted yang sudah diintegrasikan ke Godot.
2. `assets/models/` — GLB low-poly yang dipakai langsung oleh opening 3D ground chase dengan kamera perspektif.
3. `assets/**/*.svg` — source vector lama yang tetap disimpan sebagai fallback/editable reference, terutama untuk icon kecil dan dokumentasi arah bentuk.

> Status visual: sudah melewati placeholder SVG/procedural untuk banyak area. Masih belum final AAA/polished, tetapi unit top-down utama, mayoritas musuh, konvoi, support pod, boss, background stage, serta prologue ground kendaraan 3D sekarang memakai PNG/GLB asset yang nyata di Godot.

## Gameplay PNG — dipakai oleh Godot

### Player Aircraft

| File | Fungsi | Status |
| --- | --- | --- |
| `assets/rendered/player_stormhawk.png` | Pesawat utama Stormhawk. | AI-painted pass pertama. |

### Enemy Aircraft / Units

| File | Archetype | Status |
| --- | --- | --- |
| `assets/rendered/enemy_interceptor.png` | Interceptor cepat. | AI-painted pass pertama. |
| `assets/rendered/enemy_bomber.png` | Dive bomber anti-konvoi. | AI-painted pass pertama. |
| `assets/rendered/enemy_gunship.png` | Heavy gunship. | AI-painted unique pass. |
| `assets/rendered/enemy_storm_drone.png` | Drone cuaca/awan. | AI-painted unique pass. |
| `assets/rendered/enemy_tank.png` | Ground tank. | AI-painted pass pertama. |
| `assets/rendered/enemy_sam.png` | SAM launcher. | AI-painted unique pass. |
| `assets/rendered/enemy_artillery.png` | Mobile artillery. | AI-painted unique pass. |
| `assets/rendered/boss_aegis_weather_engine.png` | Blockade/boss carrier. | AI-painted boss pass pertama. |

### Convoy

| File | Role | Status |
| --- | --- | --- |
| `assets/rendered/convoy_command_truck.png` | Command Truck. | AI-painted pass pertama. |
| `assets/rendered/convoy_fuel_tanker.png` | Fuel Tanker. | AI-painted unique pass. |
| `assets/rendered/convoy_apc.png` | APC Guardian. | AI-painted unique pass. |
| `assets/rendered/convoy_supply_truck.png` | Supply Truck. | AI-painted unique pass. |

### Support Pods

| File | Aksi | Status |
| --- | --- | --- |
| `assets/rendered/support_repair_pod.png` | Heal kendaraan konvoi terdekat. | AI-painted unique pass. |
| `assets/rendered/support_smoke_pod.png` | Smoke screen. | AI-painted unique pass. |
| `assets/rendered/support_supply_pod.png` | Rearm convoy turret. | Derived from repair pod; needs unique pass. |
| `assets/rendered/support_radar_pod.png` | Reveal musuh di awan/fog. | Derived from repair pod; needs unique pass. |
| `assets/rendered/support_rod_pod.png` | Lightning rod. | Derived from smoke pod; needs unique pass. |

### Painted Stage Backgrounds

| File | Stage Usage |
| --- | --- |
| `assets/rendered/background_monsoon_pass.png` | Monsoon Pass / wet valley route. |
| `assets/rendered/background_black_delta.png` | Black Delta / Ash Harbor style fog-industrial route. |
| `assets/rendered/background_thunder_ridge.png` | Thunder Ridge / Eye of Aegis storm mountain route. |


## Gameplay GLB — dipakai oleh Opening Ground Chase 3D

| File | Fungsi | Status |
| --- | --- | --- |
| `assets/models/player_car.glb` | Mobil player untuk shootout/chase sebelum masuk aircraft. | Low-poly GLB generated, integrated. |
| `assets/models/enemy_car.glb` | Mobil musuh yang dikejar dan menembak balik. | Low-poly GLB generated, integrated. |
| `assets/models/convoy_car.glb` | Kendaraan convoy/lead visual di road phase. | Low-poly GLB generated, integrated. |
| `assets/models/support_jet.glb` | Jet support yang datang menyerang dan memicu switch ke aircraft. | Low-poly GLB generated, integrated. |

Catatan: asset GLB ini sengaja ringan untuk Web export. Mereka sudah menggantikan kebutuhan static car/jet photos, tetapi masih perlu pass model detail, material/weathering, animasi roda, VFX muzzle/jet trail final, dan collision mesh final.


## Procedural VFX — dipakai langsung oleh Godot

Tidak semua efek tembakan memakai file image baru. Pass terbaru menambahkan VFX prosedural di `scripts/main.gd`:

- Ground chase 3D: muzzle flash, bullet glow/trail, impact sparks, jet fire lance, explosion flash, dan camera shake ringan.
- Aircraft top-down: muzzle flash, tracer glow sesuai arah peluru, hit flash/shock ring, rocket smoke, overcharge laser, shield bubble, Storm Burst, dan salvage shard magnet pickup.
- Research/design reference dicatat di `docs/FX_RESEARCH.md`.

Status: pass awal sudah integrated. Masih perlu sound, sprite sheet ledakan final, smoke volumetric, dan tuning intensitas supaya tidak terlalu ramai di Web/mobile.



## Loading Screen dan Branding

Pass terbaru menambahkan asset untuk mobile loading/brand splash:

- `assets/rendered/loading_monsoon_convoy.png` — legacy key art konvoi; tidak dipakai sebagai slideshow direct Sky Force War terbaru.
- `assets/rendered/loading_thunder_hangar.png` — legacy key art hangar; tidak dipakai sebagai slideshow direct Sky Force War terbaru.
- `assets/rendered/loading_black_delta.png` — legacy key art delta; tidak dipakai sebagai slideshow direct Sky Force War terbaru.
- `assets/rendered/logo_force_war_wordmark.png` — logo/wordmark Force War: Sky Force War.
- `assets/rendered/web_boot_splash_force_war.png` — boot splash Web/Godot runtime 720x1280 (9:16), bertema Sky Force War tanpa teks Storm Convoy.
- `assets/rendered/app_icon_force_war.png` — app/favicon source untuk export Web.
- `index.png`, `index.icon.png`, `index.apple-touch-icon.png` — hasil export root yang sekarang memakai branding Force War, bukan logo Godot default.

Brand/logo dipakai oleh `GameState.LOADING` bersama stage background (`bg_thunder`, `bg_delta`, `bg_monsoon`) sebagai slideshow aircraft-only sebelum masuk title screen. Root `index.png` juga 720x1280 agar splash Web sesuai rasio 9:16.

## Current Aircraft Arena Visual Rules

- Painted stage backgrounds (`background_monsoon_pass.png`, `background_thunder_ridge.png`, `background_black_delta.png`) sekarang dipakai sebagai layer loop-scrolling vertikal selama aircraft phase, bukan satu foto statis.
- Weather cloud blobs bergerak/parallax mengikuti arena agar jalur terasa berjalan ke bawah layar.
- Mobil/konvoi tidak digambar di arena aircraft; ground-link convoy signal juga dihapus supaya game langsung terasa aircraft-only.

## UI/UX dan Progression Screens

Pass terbaru menambahkan UI procedural untuk `HANGAR & GARAGE`:

- Tab Aircraft dan Ground Car.
- Preview unit procedural/canvas.
- Stat bars dan upgrade bars.
- CTA besar untuk mobile/touch.
- Save data untuk selected vehicle, ownership, dan upgrade level.

Catatan: ini UI functional/vertical-slice. Masih perlu final icon set, animation/tween, safe-area scaling, dan style guide visual supaya semua screen konsisten.

## SVG Fallback / Reference Assets

SVG tetap ada untuk fallback, documentation, dan future vector UI pass:

- `assets/air/*.svg`
- `assets/ground/*.svg`
- `assets/convoy/*.svg`
- `assets/support/*.svg`
- `assets/weather/*.svg`

## Next Art Pass

Prioritas asset berikutnya:

1. Detail pass untuk GLB car/jet: wheel animation, wet material, dan collision mesh.
2. Upgrade VFX tembakan/Storm Burst/salvage dari procedural boxes/canvas ke sprite sheet/particle material final.
3. Boss/blockade unique per biome, bukan satu shared boss sprite.
4. Support supply/radar/rod generated unique, bukan derived tint.
5. UI/hangar/briefing background final dan icon stat vehicle.
6. Explosion/smoke/lightning VFX sprite sheets.
7. Manual edge cleanup untuk semua sprite supaya tidak ada green/white fringe.
8. Sprite atlas agar Web build lebih efisien.
