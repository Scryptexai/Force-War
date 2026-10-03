# Asset Catalog — Force War: Storm Convoy

Asset game sekarang dibagi dua lapis:

1. `assets/rendered/` — asset PNG yang dipakai langsung oleh gameplay. Ini adalah visual pass AI-painted yang sudah diintegrasikan ke Godot.
2. `assets/**/*.svg` — source vector lama yang tetap disimpan sebagai fallback/editable reference, terutama untuk icon kecil dan dokumentasi arah bentuk.

> Status visual: sudah melewati placeholder SVG/procedural. Masih belum final AAA/polished, tetapi unit utama, mayoritas musuh, konvoi, support pod, boss, dan background stage sekarang memakai PNG painted asset.

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

## SVG Fallback / Reference Assets

SVG tetap ada untuk fallback, documentation, dan future vector UI pass:

- `assets/air/*.svg`
- `assets/ground/*.svg`
- `assets/convoy/*.svg`
- `assets/support/*.svg`
- `assets/weather/*.svg`

## Next Art Pass

Prioritas asset berikutnya:

1. Boss/blockade unique per biome, bukan satu shared boss sprite.
2. Support supply/radar/rod generated unique, bukan derived tint.
3. UI/hangar/briefing background.
4. Explosion/smoke/lightning VFX sprite sheets.
5. Manual edge cleanup untuk semua sprite supaya tidak ada green/white fringe.
6. Sprite atlas agar Web build lebih efisien.
