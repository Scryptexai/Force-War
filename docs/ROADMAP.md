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
| Core escort mechanics | 45% |
| Weather gameplay | 35% |
| Route branching | 30% |
| Enemy variety logic | 35% |
| Visual production quality | 20% setelah pass PNG pertama |
| Campaign/content polish | 15% |
| Audio/VFX/juice | 5% |
| Overall menuju full version | ±25% |

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

## Milestone Produksi

### M0 — Engine dan Build Pipeline

- [x] Target engine: Godot 4.6.2 stable.
- [x] Web export template `web_nothreads_release.zip` dan `web_nothreads_debug.zip` disiapkan.
- [x] Export script diarahkan ke `4.6.2.stable`.
- [x] Output Web dibuat di root repo: `index.html`, `index.js`, `index.wasm`, `index.pck`.
- [x] Python web server dengan MIME `application/wasm` dan security headers.
- [ ] Kurangi ukuran repo/build artifact untuk production deploy.

### M1 — Combat Escort Core

- [x] Prototype konvoi multi-kendaraan dengan HP per unit.
- [x] Prototype stage clear berdasarkan progress konvoi, bukan kill count.
- [x] Prototype musuh udara menyerang pemain/konvoi.
- [x] Prototype musuh darat menyerang konvoi dari sisi jalan.
- [x] Prototype support actions: repair, smoke, supply, radar, lightning rod.
- [ ] Rework formasi konvoi supaya terasa natural dan tidak hanya mengikuti titik linear.
- [ ] Tambah AI prioritas target musuh yang lebih jelas.
- [ ] Tambah convoy behavior: panic, stop, accelerate, damaged movement, turret animation.

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
- [x] AI-painted stage background pass pertama: Monsoon Pass, Black Delta, Thunder Ridge.
- [x] Integrasi PNG gameplay sprites dan background ke Godot.
- [ ] Generate PNG unik untuk gunship, drone, SAM, artillery, semua convoy variants, support pods, boss, UI panels.
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
- [ ] Screen shake, hit-stop, damage feedback, convoy radio warning.
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
- Web export menghasilkan `index.html`, `index.js`, `index.wasm`, `index.pck` di root repo.
- Browser menjalankan game dengan server dari root repo dan header `.wasm` benar.
