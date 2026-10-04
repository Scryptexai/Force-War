# Force War: Storm Convoy — Roadmap Full Version

## Visi

Force War: Storm Convoy adalah vertical tactical escort shooter. Pemain bukan hanya membersihkan layar, tetapi menjaga konvoi darat tetap hidup sampai titik ekstraksi. Cuaca ekstrem dan cabang rute mengubah cara bermain setiap stage: environment menjadi puzzle taktis, bukan sekadar background.

## Status Realistis Saat Ini

**Build saat ini adalah vertical slice / foundation build, bukan full version final.**  
Core mechanic sudah ada, tetapi visual polish, balancing, variasi stage, audio, dan production content masih jauh dari selesai.

Estimasi kasar status produksi:

| Area | Status |
| --- | --- |
| Build/Web pipeline | 80% |
| Core escort mechanics | 51% — vehicle types mulai mempengaruhi car chase dan aircraft phase |
| Weather gameplay | 35% |
| Route branching | 30% |
| Enemy variety logic | 35% |
| Visual production quality | 42% setelah PNG/GLB + procedural VFX pass |
| Campaign/content polish | 18% — hangar/garage progression loop mulai terbentuk |
| Audio/VFX/juice | 16% — research Sky Force-style VFX + Storm Burst/salvage/laser/shield pass |
| Overall menuju full version | ±40% |

## Pilar Desain

1. **Escort sebagai objektif utama**  
   Konvoi punya beberapa kendaraan, HP per kendaraan, formasi, dan kebutuhan supply. Stage gagal jika konvoi hancur walaupun pemain masih hidup.

2. **Rute bercabang**  
   Di tengah stage muncul keputusan jalur: aman tapi lambat, pendek tapi penuh SAM/artillery, atau jalur badai dengan reward besar. Pilihan mengubah wave, cuaca, dan posisi jalan.

3. **Cuaca sebagai sistem gameplay**  
   - Angin menggeser peluru dan smoke.
   - Hujan/monsoon menurunkan visibilitas.
   - Awan menyembunyikan musuh sampai dekat/radar aktif.
   - Petir bisa overcharge senjata atau menghantam unit di zona konduktor.
   - Flooded road memperlambat konvoi dan membuatnya rentan artillery.

4. **Support pilot, bukan cuma fighter**  
   Pemain bisa drop repair, supply, radar flare, smoke screen, dan lightning rod. Loadout dipilih dari forecast sebelum mission.

5. **Original dan beda dari shooter pasaran**  
   Visual, nama unit, objective, dan sistem rute/cuaca dibuat original untuk Force War, tidak menyalin aset atau struktur level game komersial.

6. **Ground-to-air flow**
   Stage dimulai dari chase/shootout mobil 3D dengan kamera perspektif rendah/angled. Pemain mengejar dan menembak mobil musuh sampai jet support datang; baru setelah transisi itu mode top-down aircraft/Sky Force dimulai.

## Milestone Produksi

### M0 — Engine dan Build Pipeline

- [x] Target engine: Godot 4.6.2 stable.
- [x] Web export template `web_nothreads_release.zip` dan `web_nothreads_debug.zip` disiapkan.
- [x] Export script diarahkan ke `4.6.2.stable`.
- [x] Output Web dibuat di root repo: `index.html`, `index.js`, `index.wasm`, `index.pck`.
- [x] Python web server dengan MIME `application/wasm` dan security headers.
- [ ] Kurangi ukuran repo/build artifact untuk production deploy.


### M0.5 — Mobile UI/UX dan Progression Shell

- [x] Research mobile game UI/UX dan dokumentasi ATM di `docs/UI_UX_RESEARCH.md`.
- [x] Title/briefing diberi CTA besar untuk Start Mission dan Hangar/Garage.
- [x] Hangar/Garage satu layar dengan tab Aircraft dan Ground Car.
- [x] Salvage/star currency terlihat di upgrade screen.
- [x] Touch/click buttons untuk menu utama, briefing launch, hangar back/action, tabs, dan vehicle navigation.
- [ ] Safe-area/notch responsive pass untuk device mobile nyata.
- [ ] Button press animation, sound feedback, dan accessibility font scale.

### M1 — Combat Escort Core

- [x] Prototype konvoi multi-kendaraan dengan HP per unit.
- [x] Prototype stage clear berdasarkan progress konvoi, bukan kill count.
- [x] Prototype musuh udara menyerang pemain/konvoi.
- [x] Prototype musuh darat menyerang konvoi dari sisi jalan.
- [x] Prototype support actions: repair, smoke, supply, radar, lightning rod.
- [ ] Rework formasi konvoi supaya terasa natural dan tidak hanya mengikuti titik linear.
- [ ] Tambah AI prioritas target musuh yang lebih jelas.
- [ ] Tambah convoy behavior: panic, stop, accelerate, damaged movement, turret animation.

### M1.5 — 3D Ground Chase Prologue

- [x] Generate low-poly GLB `player_car`, `enemy_car`, `convoy_car`, dan `support_jet`.
- [x] Integrasi opening ground chase dengan `Node3D`, `Camera3D` perspektif angled, road mesh, lane markers, roadside props.
- [x] Mobil player dapat steer kiri/kanan dan auto-shoot enemy cars.
- [x] Enemy car GLB spawn di depan, menembak balik, dan bisa merusak mobil player.
- [x] Jet support GLB masuk/menyerang dan membuka prompt switch ke aircraft.
- [x] Pass awal efek tembakan ground: muzzle flash 3D, bullet trail, impact sparks, jet fire lance, dan camera shake ringan.
- [x] Tambah efek referensi vertical shooter: screen-clear Storm Burst, salvage pickup magnet, shield bubble, dan overcharge laser.
- [x] Transisi langsung dari ground chase ke mode top-down aircraft escort.
- [ ] Tambah physics/collision 3D yang lebih solid; saat ini collision masih logical AABB ringan.
- [ ] Tambah camera shake, road curvature, enemy chase AI, dan VFX jet attack yang lebih kuat.
- [ ] Integrasikan convoy choices/route branch ke prologue ground secara visual.


### M1.6 — Vehicle Types dan Upgrade System

- [x] Aircraft roster awal: Stormhawk Mk.I, Thunder Warden, Razorwing LX, Aegis Medic.
- [x] Ground car roster awal: Warden Rover, Lynx Pursuit, Ironback APC, Specter Rail.
- [x] Unlock cost, owned state, selected aircraft/car, dan upgrade state disimpan ke save/localStorage.
- [x] Aircraft upgrade: Main Cannon, Armor, Storm Systems level 0–5.
- [x] Car upgrade: Car Cannon, Armor, Handling level 0–5.
- [x] Aircraft stat mempengaruhi HP, speed, gun, missile, dan Storm Burst utility.
- [x] Car stat mempengaruhi HP, handling, fire-rate, dan cannon damage di ground chase.
- [ ] Model/visual unik untuk tiap aircraft dan car type; saat ini beberapa masih shared preview/model.
- [ ] Economy balancing untuk unlock/upgrade cost berdasarkan stage reward nyata.

### M2 — Branching Route System

- [x] Prototype branch prompt in-stage.
- [x] Prototype pilihan route memodifikasi threat, wind, reward, speed, dan posisi jalan.
- [x] Prototype UI menunjukkan pilihan jalur.
- [ ] Buat minimap rute yang terlihat jelas sebelum dan saat stage.
- [ ] Buat perbedaan visual nyata per branch, bukan hanya modifier angka.
- [ ] Tambah route event khusus: ambush, bridge collapse, flooded shortcut, evacuation camp.

### M3 — Extreme Weather Puzzle

- [x] Prototype forecast sebelum mission.
- [x] Prototype loadout dipilih berdasarkan forecast.
- [x] Prototype angin menggeser peluru.
- [x] Prototype rain/fog visibility overlay.
- [x] Prototype cloud cover menyembunyikan unit.
- [x] Prototype lightning strike dan overcharge weapon.
- [x] Prototype flood zones memperlambat konvoi.
- [ ] Buat weather telegraph yang mudah dibaca pemain.
- [ ] Tambah weather combo: smoke + wind drift, lightning rod chain damage, radar + hidden drones.
- [ ] Tambah VFX cuaca yang lebih kuat dan tidak sekadar overlay.

### M4 — Enemy Roster dan Boss

- [x] Prototype interceptor.
- [x] Prototype dive bomber.
- [x] Prototype gunship.
- [x] Prototype storm drone.
- [x] Prototype tank.
- [x] Prototype SAM launcher.
- [x] Prototype artillery telegraph.
- [x] Prototype mine layer / road hazard.
- [x] Prototype final blockade boss per stage.
- [ ] Buat sprite unik final untuk semua enemy, bukan tint/derived variant.
- [ ] Tambah elite variants per biome.
- [ ] Boss pattern masih perlu dibuat unik per stage.

### M5 — Visual Asset Pass

- [x] SVG placeholder/source pass untuk player, enemy, convoy, support, weather icon.
- [x] AI-painted PNG pass pertama untuk player, interceptor, bomber, tank, command truck.
- [x] AI-painted PNG pass kedua untuk gunship, drone, SAM, artillery, fuel tanker, APC, supply truck, repair pod, smoke pod, dan boss carrier.
- [x] AI-painted stage background pass pertama: Monsoon Pass, Black Delta, Thunder Ridge.
- [x] Integrasi PNG gameplay sprites, support pods, boss, dan background ke Godot.
- [ ] Generate PNG unik untuk supply/radar/rod pods, biome-specific bosses, UI panels.
- [ ] Manual cleanup alpha/edge artifact pada sprite.
- [ ] Sprite sheet / atlas agar Web build lebih efisien.
- [ ] Particle polish per weather.

### M6 — Campaign Content

- [x] 6 operation skeleton: Monsoon Pass, Forked Canyon, Black Delta, Thunder Ridge, Ash Harbor, Eye of Aegis.
- [x] Forecast unik tiap operation.
- [x] Route branch unik tiap operation.
- [ ] Tuning durasi, spawn table, reward economy.
- [ ] Narrative radio chatter.
- [ ] Mission objective variants: evacuate civilians, protect fuel, suppress SAM corridor, thunder rod escort.

### M7 — Audio, Feel, dan Web Polish

- [x] JavaScriptBridge state/events.
- [x] localStorage save.
- [ ] Sound FX procedural / open-license.
- [x] Pass awal VFX tembakan prosedural: muzzle flash, tracer glow, hit flash, rocket smoke, dan 3D ground sparks.
- [x] Research efek Sky Force-style dan catat jenis efek utama di `docs/FX_RESEARCH.md`.
- [x] Storm Burst `B`: radial screen-clear pulse, clear bullets, damage area, screen flash/shake.
- [x] Salvage shards/magnet pickup dari musuh hancur.
- [x] Overcharge laser beam dan shield bubble saat invulnerable.
- [ ] Screen shake/hit-stop final, damage feedback, convoy radio warning.
- [ ] Responsive mobile HUD final.
- [ ] Touch radial support actions.
- [ ] Add host page overlay for bridge debug/events.

## Acceptance Criteria v1.0

- Konvoi bisa menang/kalah terpisah dari HP pemain.
- Minimal 6 stage campaign playable dan visually distinct.
- Setiap stage punya weather forecast, branching route, boss/blockade unik.
- Minimal 8 enemy archetype dengan sprite PNG unik dan behavior berbeda.
- Minimal 5 support/loadout tools dengan VFX/sprite unik.
- Minimal 3 biome background final dan 3 derivative stage variants.
- Opening stage menampilkan 3D ground car chase memakai GLB/Godot mesh dan kamera perspektif non-top-down.
- Transisi ground-to-air terjadi setelah jet support masuk; top-down hanya untuk aircraft phase.
- Web export menghasilkan `index.html`, `index.js`, `index.wasm`, `index.pck` di root repo.
- Browser menjalankan game dengan server dari root repo dan header `.wasm` benar.
