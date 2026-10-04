# Force War — Mobile UI/UX + ATM Design Research

Tanggal: 2026-10-04

## Prinsip Mobile Game UI/UX yang Diambil

1. **Thumb-first layout**
   - Aksi utama ditempatkan di area bawah dan tengah-bawah agar mudah dijangkau jempol.
   - Tombol penting dibuat besar, bukan icon kecil.

2. **Touch target besar**
   - Minimum target mengacu praktik mobile umum: sekitar 44 pt iOS / 48 dp Android.
   - Di Force War, tombol menu utama dibuat ±54 px tinggi dengan margin cukup.

3. **Progressive disclosure**
   - Jangan tampilkan semua kompleksitas sejak title.
   - Title hanya punya dua CTA: Start Mission dan Hangar/Garage.
   - Upgrade detail dipindah ke satu layar Hangar/Garage.

4. **One-screen upgrade flow**
   - Inspired by garage/hangar UI UX: hindari terlalu banyak nested menu.
   - Pilih unit, lihat status, lihat stat, pilih upgrade, lalu upgrade dari layar yang sama.

5. **Immediate feedback**
   - Semua aksi upgrade/buy memberi warning/feedback text.
   - Status locked/owned/cost terlihat jelas tanpa harus masuk submenu.

6. **Short-session mobile loop**
   - Briefing → Hangar check → Launch harus cepat.
   - Pemain bisa tetap langsung launch tanpa wajib mengatur upgrade.

7. **Clear hierarchy**
   - Currency/salvage di atas.
   - Tabs Aircraft/Ground Car di atas.
   - Unit preview di tengah.
   - Upgrade actions di bawah.

## ATM — Amati, Tiru, Modifikasi

Metode ATM dipakai sebagai proses desain, bukan menyalin aset/IP:

### Amati
- Sky Force: hangar/progression kuat, upgrade pesawat, star economy, power-up clarity.
- Mobile games: bottom actions, besar, jelas, cepat, feedback instan.
- Vehicle games/garage UI: pilih kendaraan, lihat stat, upgrade komponen dari satu panel.

### Tiru
- Pola yang ditiru: bukan aset, melainkan **alur UX**:
  - currency selalu terlihat,
  - kendaraan punya card/stat,
  - upgrade punya level bar dan cost,
  - locked/owned jelas,
  - tombol action besar.

### Modifikasi
- Force War memakai identitas sendiri:
  - dua kategori unit: aircraft dan ground car,
  - upgrade mempengaruhi fase berbeda: car untuk chase 3D, aircraft untuk top-down escort,
  - economy disebut salvage stars,
  - Storm Burst / weather systems tetap sesuai tema escort cuaca ekstrem.

## Implementasi Pass Ini

- Tambah screen `HANGAR & GARAGE`.
- Tambah tab `AIRCRAFT` dan `GROUND CAR`.
- Tambah 4 aircraft type:
  - Stormhawk Mk.I
  - Thunder Warden
  - Razorwing LX
  - Aegis Medic
- Tambah 4 car type:
  - Warden Rover
  - Lynx Pursuit
  - Ironback APC
  - Specter Rail
- Tambah ownership/unlock cost.
- Tambah upgrade level 0–5:
  - Aircraft: Main Cannon, Armor, Storm Systems.
  - Car: Car Cannon, Armor, Handling.
- Upgrade dan selected vehicle disimpan ke save data / localStorage.
- Aircraft stat mempengaruhi HP, speed, gun, missile, utility/Storm Burst.
- Car stat mempengaruhi HP mobil, handling ground chase, fire-rate, dan damage cannon.

## Next UI/UX Tasks

- Tambahkan animation tween untuk menu transition/button press.
- Tambahkan touch radial support tools saat gameplay.
- Tambahkan safe-area scaling untuk notch/gesture bar mobile.
- Tambahkan stat comparison sebelum/sesudah upgrade.
- Tambahkan icon final untuk aircraft/car stats.
- Tambahkan tutorial level zero: steer car, shoot, switch aircraft, protect convoy.
- Tambahkan audio/haptic-like feedback via screen pulse/sound.
