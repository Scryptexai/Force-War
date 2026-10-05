# Force War — Mobile UI/UX Flow Audit for Forward 3D Redesign

Tanggal redesign lock: 2026-10-05

## 1. Flow Baru yang Diinginkan

```text
Loading / Force War Brand Splash
  → Title
    → Mission Briefing + Weather Forecast
      → Aircraft Hangar / Loadout
        → Forward 3D Air Mission
          → Stage Clear / Game Over
            → Rewards / Upgrade Prompt
              → Briefing / Hangar
```

Flow lama yang berisi ground chase, garage car, convoy escort, atau top-down aircraft transition **tidak lagi menjadi target**.

## 2. Mandatory Mobile Requirements

- Loading page tetap wajib untuk Web/mobile.
- 9:16 portrait tetap dipertahankan.
- HUD harus thumb-safe.
- Core action harus bisa dimainkan dengan drag/touch satu jari + ability buttons.
- UI tidak boleh menutupi dodge/aim zone di tengah layar.
- Reticle/lock-on marker harus jelas karena target berada di depth 3D.

## 3. HUD Layout Target

```text
Top-left       : Player HP / shield / aircraft status
Top-center     : Boss HP / current objective
Top-right      : Score / combo / pause
Center         : Reticle, target brackets, warning markers
Lower-left     : Ability buttons: missile, shield, storm burst / overcharge
Lower-right    : Radar/weather mini-map + optional boost/dodge
Bottom-center  : Player aircraft GLB visible, avoid heavy UI overlap
```

## 4. Changes from Old UX

| Old UX | New UX |
| --- | --- |
| Hangar/Garage includes cars | Aircraft hangar only |
| Mission implies convoy escort | Mission is forward air assault / storm corridor |
| Route shown as ground/road choices | Route shown as air corridor/weather cell choices |
| Top-down support buttons | Forward flight ability buttons + lock-on reticle |
| Loading art includes convoy/hangar car themes | Loading art should match aircraft storm war only |

## 5. Briefing Screen Target

Before mission, player sees:

- operation name;
- storm/weather forecast;
- enemy/boss intel silhouette;
- recommended loadout;
- route/corridor risk preview;
- aircraft selected and upgrade summary.

No car/convoy language.

## 6. Aircraft Hangar Target

Hangar should include:

- selected 3D aircraft preview or turntable;
- upgrade categories:
  - main cannon;
  - wing cannon;
  - missiles;
  - shield/armor;
  - storm systems;
  - engine/handling;
- clear cost/owned/upgrade state;
- CTA: Launch, Upgrade, Back.

## 7. In-Mission Forward Flight UX

Because camera is behind aircraft:

- crosshair/reticle sits ahead of aircraft, not on aircraft;
- incoming missile warnings should appear from depth direction;
- boss weakpoints need target brackets;
- lock-on missiles need progress ring;
- weather hazards need corridor markers/ghost lanes.

## 8. Loading and Branding

Current loading system can remain as shell, but art must be cleaned:

- Keep Force War logo/wordmark if still matching.
- Regenerate/remove loading backgrounds that visibly show convoy/car themes.
- Loading slideshow should show aircraft, storm sky, dreadnought, ocean/city warzone, lightning.

## 9. Next UX Tasks

- Remove Garage Car tab and car upgrade state from UI after code rewrite.
- Add 3D aircraft preview in hangar.
- Add flight reticle and lock-on marker.
- Add weather corridor choice UI.
- Add touch-safe ability layout for forward camera.
- Add camera/tutorial onboarding: drag to steer, hold fire/auto-fire, missile, shield, boost.
