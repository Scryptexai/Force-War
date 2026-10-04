# Force War — Mobile UI/UX Flow Audit

Tanggal: 2026-10-04

## Flow Utama Setelah Pass Ini

```text
Loading / Brand Splash
  → Title
    → Mission Briefing
      → Hangar/Garage optional
      → Ground Chase 3D
      → Aircraft Escort Phase
      → Stage Clear / Game Over
      → Briefing
```

## Temuan UX Mobile

1. **Loading page wajib untuk mobile**
   - Sebelum pass ini game langsung ke title, jadi tidak ada momen branding dan tidak ada buffer visual untuk Web/Godot load.
   - Sekarang ditambahkan `GameState.LOADING` sebagai layar pertama.

2. **Brand recall**
   - Logo wordmark `FORCE WAR: SKY FORCE WAR` muncul di loading dan title.
   - Ini membantu game terlihat seperti produk lengkap, bukan debug prototype.

3. **Slideshow background loading**
   - Loading screen memakai beberapa key art background sesuai tema game:
     - convoy dalam badai monsoon,
     - hangar pesawat/mobil support,
     - delta banjir dengan jet dan drone.
   - Gambar berganti otomatis dengan crossfade.

4. **Mobile readability**
   - Loading memakai dark overlay atas/bawah supaya logo, loading bar, dan tips tetap terbaca di layar kecil.
   - Loading bar besar dan berada di thumb-safe lower area.

5. **Tap to skip / continue**
   - Setelah branding minimal terlihat, tap/click/keyboard bisa mempercepat masuk title.
   - Jika tidak disentuh, loading auto-complete ke title.

## Asset Baru

```text
assets/rendered/loading_monsoon_convoy.png
assets/rendered/loading_thunder_hangar.png
assets/rendered/loading_black_delta.png
assets/rendered/logo_force_war_wordmark.png
```

## Implementasi Teknis

- `GameState.LOADING` ditambahkan ke `scripts/main.gd`.
- Loading state mempunyai:
  - slideshow key art,
  - progress bar,
  - tips rotator,
  - logo wordmark,
  - tap/keyboard skip.
- `load_textures()` memuat key art dan logo sebagai texture Godot.
- `draw_texture_cover()` ditambahkan supaya image loading dicrop/cover ke portrait canvas 720×960.

## Next UI/UX Improvements

- Tambahkan animated company/studio splash singkat.
- Tambahkan first-time onboarding ringan setelah title.
- Tambahkan save-aware loading tips berdasarkan progress/upgrade pemain.
- Tambahkan touch-safe calibration untuk device notch/gesture bar.
- Tambahkan A/B layout untuk title CTA agar lebih mirip mobile game premium.
