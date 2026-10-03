# Asset Catalog — Force War: Storm Convoy

Asset game sekarang dibagi dua lapis:

1. `assets/rendered/` — asset PNG yang dipakai langsung oleh gameplay. Ini adalah visual pass pertama dengan AI-painted sprites/backgrounds.
2. `assets/**/*.svg` — placeholder/source vector lama yang tetap disimpan sebagai fallback/editable reference, terutama untuk support pod dan icon kecil.

> Catatan jujur: pass ini meningkatkan game dari placeholder SVG/procedural menjadi PNG painted asset, tetapi belum final. Beberapa unit masih derivative/tinted karena limit generate image per turn. Roadmap sekarang menandai visual sebagai masih sekitar 20%, bukan selesai.

## Gameplay PNG — dipakai oleh Godot

### Player Aircraft

| File | Fungsi |
| --- | --- |
| `assets/rendered/player_stormhawk.png` | Pesawat utama Stormhawk. |

### Enemy Aircraft / Units

| File | Archetype | Status |
| --- | --- | --- |
| `assets/rendered/enemy_interceptor.png` | Interceptor | AI-painted sprite pass pertama. |
| `assets/rendered/enemy_bomber.png` | Dive bomber | AI-painted sprite pass pertama, cleanup putih/checker dilakukan dengan ImageMagick. |
| `assets/rendered/enemy_gunship.png` | Gunship | Derived/tinted dari bomber sementara; perlu generated unik. |
| `assets/rendered/enemy_storm_drone.png` | Storm drone | Derived/tinted dari interceptor sementara; perlu generated unik. |
| `assets/rendered/enemy_tank.png` | Tank | AI-painted sprite pass pertama, cleanup checker dilakukan dengan ImageMagick. |
| `assets/rendered/enemy_sam.png` | SAM launcher | Derived/tinted dari tank sementara; perlu generated unik. |
| `assets/rendered/enemy_artillery.png` | Artillery | Derived/tinted dari tank sementara; perlu generated unik. |

### Convoy

| File | Role | Status |
| --- | --- | --- |
| `assets/rendered/convoy_command_truck.png` | Command Truck | AI-painted sprite pass pertama. |
| `assets/rendered/convoy_fuel_tanker.png` | Fuel Tanker | Derived/tinted sementara; perlu generated unik. |
| `assets/rendered/convoy_apc.png` | APC Guardian | Derived/tinted sementara; perlu generated unik. |
| `assets/rendered/convoy_supply_truck.png` | Supply Truck | Derived/tinted sementara; perlu generated unik. |

### Painted Stage Backgrounds

| File | Stage Usage |
| --- | --- |
| `assets/rendered/background_monsoon_pass.png` | Monsoon Pass / wet valley route. |
| `assets/rendered/background_black_delta.png` | Black Delta / Ash Harbor style fog-industrial route. |
| `assets/rendered/background_thunder_ridge.png` | Thunder Ridge / Eye of Aegis storm mountain route. |

## SVG Fallback / UI Assets

### Support Pods

| File | Aksi |
| --- | --- |
| `assets/support/repair_pod.svg` | Heal kendaraan konvoi terdekat. |
| `assets/support/smoke_pod.svg` | Smoke screen, mengurangi akurasi/damage musuh ke konvoi. |
| `assets/support/supply_pod.svg` | Rearm convoy turret dan memberi skor sustain. |
| `assets/support/radar_pod.svg` | Reveal musuh di awan/fog. |
| `assets/support/rod_pod.svg` | Lightning rod untuk menarik petir/overcharge area. |

### Weather Icons

| File | Sistem |
| --- | --- |
| `assets/weather/storm_icon.svg` | Thunderstorm/lightning. |
| `assets/weather/rain_icon.svg` | Heavy rain/monsoon visibility. |
| `assets/weather/wind_icon.svg` | Wind drift. |
| `assets/weather/cloud_icon.svg` | Cloud concealment/fog. |

## Next Art Pass

Prioritas asset berikutnya:

1. Boss/blockade PNG unik per biome.
2. Gunship, drone, SAM, artillery PNG unik, bukan derivative.
3. Fuel tanker, APC, supply truck PNG unik.
4. Support pod PNG with impact VFX.
5. UI/hangar/briefing background.
6. Manual edge cleanup untuk semua sprite supaya tidak ada green/white fringe.
