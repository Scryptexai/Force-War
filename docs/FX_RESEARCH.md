# Force War VFX Research Notes

Tanggal: 2026-10-04

Tujuan: memperkuat efek tembakan dan feedback agar Force War terasa lebih dekat dengan standar vertical shooter modern seperti Sky Force, tetapi tetap original dan tidak menyalin aset/visual spesifik.

## Referensi yang Diteliti

- Sky Force Reloaded wiki/Fandom: menyebut flashy explosions, massive bosses, collectable planes, stars, upgrades, Laser, Energy Shield, Mega Bomb, Magnet, missiles, radial cannons, homing missiles, and boss phase/explosion emphasis.
- Nintendo / PlayStation store pages: menekankan meaty explosions, incinerating lasers, colossal bosses, beautiful environments, intense effects, and collectibles.
- Review TheXboxHub / WindowsCentral: menekankan bullet storm, star collection/magnetism, wing cannons, homing missiles, lasers, shield, mega bomb, objective medals, survivor rescue, crates/cards, and progression.

## Jenis Efek yang Relevan

1. **Muzzle flash**
   - Kilatan di ujung senjata player/enemy.
   - Harus singkat, terang, dan sesuai arah peluru.

2. **Tracer / bullet trail**
   - Jalur cahaya pendek di belakang projectile.
   - Penting untuk membaca arah bullet storm.

3. **Hit flash + shock ring**
   - Saat peluru kena musuh/player/konvoi, perlu ledakan kecil + ring.
   - Membuat damage terasa, tidak hanya angka HP turun.

4. **Layered explosion**
   - Ledakan harus punya core flash, spark, smoke, shockwave, dan screen shake berbeda untuk unit kecil/boss.

5. **Laser beam**
   - Beam tebal dengan glow luar, inti putih, damage line, dan impact sparks sepanjang jalur.
   - Di Force War dipakai sebagai overcharge laser saat lightning memberi buff.

6. **Shield bubble**
   - Bubble/arc saat player invulnerable atau dilindungi.
   - Mengganti blink sederhana agar feedback lebih jelas.

7. **Mega bomb / screen clear pulse**
   - Radial shockwave besar yang menghapus peluru dan memberi damage luas.
   - Di Force War disebut **Storm Burst** supaya tetap original.

8. **Collectible star / magnet trail**
   - Pickup kecil keluar dari musuh mati, lalu tertarik ke player.
   - Di Force War disebut salvage shards; memberi score/stars dan feedback farming.

9. **Boss death spectacle**
   - Boss harus punya multi-layer explosion lebih besar dari musuh biasa.
   - Saat ini baru procedural first pass; nanti perlu sprite sheet/VFX final.

10. **Weather interaction VFX**
    - Lightning overcharge, storm flash, wind bending projectile, rain/fog overlay.
    - Ini pembeda Force War dari shooter standar.

## Implementasi Pass Ini

- Added 2D muzzle flash for player, enemies, boss, and convoy turret shots.
- Added projectile tracer glow with direction-aware line width.
- Added hit flash + shock ring for bullet impact and hazard explosions.
- Added overcharge laser beam while lightning overcharge is active.
- Added player shield bubble/arc during invulnerability.
- Added Storm Burst on `B`: screen-clear pulse, enemy bullet clear, area damage, screen flash, and shake.
- Added salvage shard pickups from destroyed enemies with magnet-like attraction to player.
- Expanded 3D ground chase fire feedback: muzzle flash, trails, impact sparks, jet fire lance, and camera shake.

## Next VFX Tasks

- Replace procedural shapes with particle materials / sprite sheets for explosions and smoke.
- Add audio coupling: cannon, laser, shield hum, burst, pickup chime, explosion layers.
- Add hit-stop and stronger directional screen shake for boss/explosive impacts.
- Add actual 3D particle systems for ground muzzle smoke and jet afterburner.
- Add UI medal feedback and rescue/supply completion flourishes.
