# Web Loading Performance & Splash Cleanup

Date: 2026-10-05

## User-visible issue

The screenshot showed the browser stuck on the Godot Web boot/progress page for too long, and the splash still showed old road/car/convoy-themed art plus the old `SKY FORCE WAR` wording.

## Cause

This was not mainly a gameplay loop bug. The browser had to download and initialize the exported Godot Web payload before the game could draw its own canvas:

- `index.wasm` is the Godot Web runtime and remains about 36 MB uncompressed.
- `index.pck` had grown to about 37.5 MB because the export still packed legacy/high-resolution assets, including old loading/background art and duplicate/source model texture files.
- The Godot boot splash image was still `assets/rendered/web_boot_splash_force_war.png`, which had road/car/convoy visual language and old text.
- The in-game loading screen also had an artificial 4.8 second hold.

## Fixes made

- Replaced Web/Godot boot splash with forward-air arena branding.
- Rebuilt the logo wordmark to say `FORWARD AIR COMBAT`, removing the old `SKY FORCE WAR` subtitle.
- Added three lightweight forward-arena loading slideshow images:
  - `assets/rendered/loading_forward_arena_01.jpg`
  - `assets/rendered/loading_forward_arena_02.jpg`
  - `assets/rendered/loading_forward_arena_03.jpg`
- Removed old loading images that showed road/convoy/hangar/car visuals:
  - `assets/rendered/loading_monsoon_convoy.png`
  - `assets/rendered/loading_thunder_hangar.png`
  - `assets/rendered/loading_black_delta.png`
- Reduced the in-game loading hold from `4.8s` to `1.35s`.
- Updated export filters so legacy road/loading/background/source assets are no longer packed into `index.pck`.
- Reduced `index.pck` from about `37.5 MB` to about `6.4 MB`.
- Added local server ETag/revalidation and gzip streaming for large Godot files.
- Added QA guard so `index.pck` fails `npm run vercel-build` if it grows beyond `16 MB` again.

## Remaining note

`index.wasm` is still the Godot Web runtime and is expected to be large. On a cold browser cache, the first boot can still take time while WebAssembly downloads and initializes. Subsequent loads should be much faster due browser caching/revalidation.
