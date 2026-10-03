# Force War: Storm Convoy — Roadmap Full Version

## Visi

Force War: Storm Convoy adalah vertical tactical escort shooter. Pemain bukan hanya membersihkan layar, tetapi menjaga konvoi darat tetap hidup sampai titik ekstraksi. Cuaca ekstrem dan cabang rute mengubah cara bermain setiap stage: environment menjadi puzzle taktis, bukan sekadar background.

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

### M0 — Upgrade Engine dan Build Pipeline

- [x] Target engine: Godot 4.6.2 stable.
- [x] Web export template `web_nothreads_release.zip` dan `web_nothreads_debug.zip` disiapkan.
- [x] Export script diarahkan ke `4.6.2.stable`.
- [x] Python web server dengan MIME `application/wasm` dan security headers.
- [ ] Ganti binary Linux 4.6.2 yang corrupt/truncated di repo dengan zip/binary resmi yang valid.

### M1 — Combat Escort Core

- [x] Konvoi multi-kendaraan dengan HP per unit.
- [x] Stage clear berdasarkan progress konvoi, bukan kill count.
- [x] Musuh udara menyerang pemain/konvoi.
- [x] Musuh darat menyerang konvoi dari sisi jalan.
- [x] Support actions: repair, smoke, supply, radar, lightning rod.

### M2 — Branching Route System

- [x] Branch prompt in-stage.
- [x] Pilihan route memodifikasi threat, wind, reward, speed, dan posisi jalan.
- [x] UI menunjukkan pilihan jalur.
- [ ] Tambah preview minimap rute tiap stage.

### M3 — Extreme Weather Puzzle

- [x] Forecast sebelum mission.
- [x] Loadout dipilih berdasarkan forecast.
- [x] Angin menggeser peluru.
- [x] Rain/fog visibility overlay.
- [x] Cloud cover menyembunyikan unit.
- [x] Lightning strike dan overcharge weapon.
- [x] Flood zones memperlambat konvoi.
- [ ] Tambah weather combo: smoke + wind drift, lightning rod chain damage.

### M4 — Enemy Roster dan Boss

- [x] Interceptor.
- [x] Dive bomber.
- [x] Gunship.
- [x] Storm drone.
- [x] Tank.
- [x] SAM launcher.
- [x] Artillery telegraph.
- [x] Mine layer / road hazard.
- [x] Final blockade boss per stage.
- [ ] Tambah elite variants per biome.

### M5 — Asset Pass

- [x] Generate SVG assets untuk player aircraft, musuh, ground vehicles, convoy, support pods, weather icons.
- [x] Integrasi texture draw fallback ke procedural shapes.
- [ ] Sound FX procedural / open-license.
- [ ] Particle polish per weather.

### M6 — Campaign Content

- [x] 6 operation skeleton: Monsoon Pass, Forked Canyon, Black Delta, Thunder Ridge, Ash Harbor, Eye of Aegis.
- [x] Forecast unik tiap operation.
- [x] Route branch unik tiap operation.
- [ ] Tuning durasi, spawn table, reward economy.
- [ ] Narrative radio chatter.

### M7 — Web Polish

- [x] JavaScriptBridge state/events.
- [x] localStorage save.
- [ ] Responsive mobile HUD final.
- [ ] Touch radial support actions.
- [ ] Add host page overlay for bridge debug/events.

## Acceptance Criteria v1.0

- Konvoi bisa menang/kalah terpisah dari HP pemain.
- Minimal 6 stage campaign playable.
- Setiap stage punya weather forecast, branching route, dan boss/blockade.
- Minimal 8 enemy archetype.
- Minimal 5 support/loadout tools.
- Web export menghasilkan `index.html`, `index.js`, `index.wasm`, `index.pck`.
- Browser menjalankan game dengan server Python dan header `.wasm` benar.
