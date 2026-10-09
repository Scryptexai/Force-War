#!/usr/bin/env node
import { existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import chromiumPack, { inflate, setupLambdaEnvironment } from '@sparticuz/chromium';
import { chromium as playwrightChromium } from 'playwright-core';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sparticuzBin = join(root, 'node_modules', '@sparticuz', 'chromium', 'bin');
const port = Number(process.env.QA_FORWARD_PORT || 8700 + Math.floor(Math.random() * 400));

function fail(message) {
  console.error(`Forward flight QA failed: ${message}`);
  process.exit(1);
}

async function waitForHealth(serverProcess) {
  const started = Date.now();
  let lastError = '';
  while (Date.now() - started < 30000) {
    if (serverProcess.exitCode !== null) fail(`server.js exited early with ${serverProcess.exitCode}`);
    try {
      const response = await fetch(`http://127.0.0.1:${port}/healthz`);
      if (response.ok) return;
      lastError = `${response.status} ${response.statusText}`;
    } catch (error) {
      lastError = error.message;
    }
    await new Promise((resolveDelay) => setTimeout(resolveDelay, 250));
  }
  fail(`server.js did not become healthy: ${lastError}`);
}

async function launchBrowser() {
  if (existsSync(join(sparticuzBin, 'al2023.tar.br'))) {
    await inflate(join(sparticuzBin, 'al2023.tar.br'));
    setupLambdaEnvironment(join(tmpdir(), 'al2023', 'lib'));
  }
  const executablePath = process.env.CHROMIUM_PATH || await chromiumPack.executablePath();
  return playwrightChromium.launch({
    executablePath,
    headless: true,
    args: [
      ...chromiumPack.args,
      '--no-sandbox',
      '--disable-dev-shm-usage',
      '--ignore-gpu-blocklist',
      '--enable-webgl'
    ]
  });
}

async function main() {
  const serverProcess = spawn(process.execPath, ['server.js'], {
    cwd: root,
    env: { ...process.env, PORT: String(port), HOST: '0.0.0.0' },
    stdio: ['ignore', 'pipe', 'pipe']
  });
  let serverLog = '';
  serverProcess.stdout.on('data', (chunk) => { serverLog += chunk.toString(); });
  serverProcess.stderr.on('data', (chunk) => { serverLog += chunk.toString(); });

  try {
    await waitForHealth(serverProcess);
    const browser = await launchBrowser();
    const pageErrors = [];
    try {
      const page = await browser.newPage({
        viewport: { width: 720, height: 1280 },
        deviceScaleFactor: 1,
        isMobile: true,
        hasTouch: true
      });
      page.on('pageerror', (error) => pageErrors.push(error.message));
      await page.goto(`http://127.0.0.1:${port}/index.html`, { waitUntil: 'domcontentloaded', timeout: 60000 });
      await page.waitForSelector('canvas', { timeout: 60000 });
      await page.waitForFunction(() => !!window.ForceWarBridge, null, { timeout: 60000 });
      await page.click('canvas', { position: { x: 360, y: 640 } });

      // Skip loading after the minimum brand hold, then enter briefing and launch mission.
      await page.waitForTimeout(1600);
      await page.keyboard.press('Space');
      await page.waitForTimeout(900);
      await page.keyboard.press('Space');
      await page.waitForTimeout(700);
      await page.keyboard.press('Space');

      await page.waitForFunction(() => window.ForceWarBridge?.state?.missionMode === 'forward_air_combat', null, { timeout: 30000 });
      await page.waitForFunction(() => window.ForceWarBridge?.state?.cameraMode === 'chase_behind_above', null, { timeout: 10000 });
      await page.waitForFunction(() => window.ForceWarBridge?.state?.bossPatternScheduler === true, null, { timeout: 10000 });
      await page.waitForFunction(() => Number(window.ForceWarBridge?.state?.playerProjectileHits || 0) > 0, null, { timeout: 15000 });
      await page.waitForFunction(() => Number(window.ForceWarBridge?.state?.bossFireEventCount || 0) > 0, null, { timeout: 20000 });
      await page.waitForFunction(() => Number(window.ForceWarBridge?.state?.bossProjectileHitCount || 0) > 0, null, { timeout: 20000 });
      const result = await page.evaluate(() => {
        const canvas = document.querySelector('canvas');
        return {
          state: window.ForceWarBridge?.state || null,
          canvas: canvas ? { width: canvas.width, height: canvas.height } : null
        };
      });
      if (pageErrors.length > 0) fail(`browser page errors: ${pageErrors.join(' | ')}`);
      if (!result.canvas || result.canvas.width !== 720 || result.canvas.height !== 1280) {
        fail(`expected 720x1280 canvas, got ${result.canvas?.width}x${result.canvas?.height}`);
      }
      if (result.state?.playerModel !== 'glb') fail(`expected playerModel glb, got ${result.state?.playerModel}`);
      if (result.state?.playerModelSource !== 'res://assets/models/player_mig29_blender_ready.glb') fail(`expected Blender-prepared uploaded GLB player source, got ${result.state?.playerModelSource}`);
      if (result.state?.playerModelAssetAuthenticity !== 'uploaded_glb_blender_prepared_runtime_instance') fail(`player GLB authenticity failed: ${result.state?.playerModelAssetAuthenticity}`);
      if (result.state?.playerModelOriginalSource !== 'res://source_assets/HERO_fighter_jet.glb') fail(`player original GLB source contract failed: ${result.state?.playerModelOriginalSource}`);
      if (result.state?.playerForwardAxis !== 'negative_z') fail(`player forward axis contract missing: ${result.state?.playerForwardAxis}`);
      // The hull is now authored in Blender with the nose already on the Godot
      // forward axis, so the engine applies no corrective rotation at all.
      if (result.state?.playerModelAlignment !== 'blender_authored_nose_on_forward_axis_no_engine_rotation') fail(`player GLB alignment contract missing: ${result.state?.playerModelAlignment}`);
      if (result.state?.runtimeAfterburnerBoxes !== false) fail(`runtime fallback afterburner boxes should be disabled: ${result.state?.runtimeAfterburnerBoxes}`);
      if (result.state?.playerWeaponHardpointBinding !== 'glb_socket_runtime') fail(`player weapon hardpoint binding missing: ${result.state?.playerWeaponHardpointBinding}`);
      if (result.state?.playerGLBWeaponSocketsFound !== true) fail(`player GLB weapon sockets were not found: ${result.state?.playerGLBWeaponSocketsFound}`);
      if (result.state?.playerShotSpawnOrigin !== 'glb_muzzle_socket') fail(`player shot spawn origin not bound to GLB socket: ${result.state?.playerShotSpawnOrigin}`);
      if (result.state?.logicalPlayerShotOrigin !== 'glb_muzzle_socket') fail(`logical player shot origin not bound to GLB socket: ${result.state?.logicalPlayerShotOrigin}`);
      if (typeof result.state?.playerMuzzleCenterZ !== 'number') fail(`player muzzle center bridge missing: ${result.state?.playerMuzzleCenterZ}`);
      if (Number(result.state?.playerMuzzleForwardOffset) >= -0.1) fail(`player muzzle socket is not ahead of the hull: ${result.state?.playerMuzzleForwardOffset}`);
      if (result.state?.playerMuzzleForwardZLocked !== true) fail(`player muzzle forward-Z lock missing: ${result.state?.playerMuzzleForwardZLocked}`);
      if (result.state?.socketMuzzleVFX !== 'glb_socket_cyan_forward_burst') fail(`socket muzzle VFX mode missing: ${result.state?.socketMuzzleVFX}`);
      if (result.state?.socketMuzzleVFXActive !== true) fail(`socket muzzle VFX not active: ${result.state?.socketMuzzleVFXActive}`);
      if (Number(result.state?.socketMuzzleVFXCount || 0) < 4) fail(`expected socket muzzle VFX pair nodes, got ${result.state?.socketMuzzleVFXCount}`);
      if (result.state?.playerShotVisibleFromSocket !== true) fail(`shot is not visibly socket-anchored: ${result.state?.playerShotVisibleFromSocket}`);
      if (result.state?.foundationCorrectionPass !== 'pass_1_combat_causality_and_playfield') fail(`pass 1 correction marker missing: ${result.state?.foundationCorrectionPass}`);
      if (result.state?.shotDirectionMode !== 'xz_plane_velocity_aligned') fail(`shot direction model regression: ${result.state?.shotDirectionMode}`);
      if (result.state?.shotVisualOrientation !== 'velocity_aligned_flat_on_combat_plane') fail(`shot visual orientation still unsafe: ${result.state?.shotVisualOrientation}`);
      if (result.state?.playerShotFromHardpoint !== true) fail(`shot hardpoint contract missing: ${result.state?.playerShotFromHardpoint}`);
      if (result.state?.foundationVisualMode !== true) fail(`foundation clean visual mode missing: ${result.state?.foundationVisualMode}`);
      if (result.state?.backgroundClutterMode !== 'foundation_clean') fail(`background clutter mode not clean: ${result.state?.backgroundClutterMode}`);
      if (result.state?.legacyVerticalShotColumns !== false) fail(`legacy vertical shot columns still enabled: ${result.state?.legacyVerticalShotColumns}`);
      if (Number(result.state?.legacyNearCameraCyanPulseNodes || 0) !== 0) fail(`legacy near-camera cyan pulse nodes should be disabled: ${result.state?.legacyNearCameraCyanPulseNodes}`);
      if (result.state?.rainGeometryMode !== 'haze_only_no_vertical_columns') fail(`rain geometry mode can read as vertical columns: ${result.state?.rainGeometryMode}`);
      if (Number(result.state?.nearRainSheetCount || 0) !== 0) fail(`near rain sheets should stay disabled in forward visual lock: ${result.state?.nearRainSheetCount}`);
      if (result.state?.active !== true) fail(`forward scene was not active: ${JSON.stringify(result.state)}`);
      if (result.state?.arenaPhase !== 'storm_battlefield') fail(`expected storm_battlefield arena phase, got ${result.state?.arenaPhase}`);
      if (Number(result.state?.depthLayerCount || 0) < 4) fail(`expected at least 4 depth layers, got ${result.state?.depthLayerCount}`);
      if (result.state?.weatherGameplay !== true) fail(`weather gameplay flag missing: ${JSON.stringify(result.state)}`);
      if (typeof result.state?.windDrift !== 'number') fail('windDrift was not numeric');
      if (typeof result.state?.rainVisibility !== 'number') fail('rainVisibility was not numeric');
      if (typeof result.state?.cloudCover !== 'number') fail('cloudCover was not numeric');
      if (typeof result.state?.stormHazard !== 'number') fail('stormHazard was not numeric');
      if (result.state?.bossAnchor !== true) fail(`boss anchor missing: ${JSON.stringify(result.state)}`);
      // Pass 1 replaced the matte-painting composition with a real boss entity.
      if (result.state?.staticMatteBackdrop !== false) fail(`static matte backdrop returned: ${result.state?.staticMatteBackdrop}`);
      if (result.state?.bossWeakpointVisual !== true) fail(`boss weakpoint visual missing: ${result.state?.bossWeakpointVisual}`);
      if (result.state?.bossWeakpointSocketBinding !== 'boss_entity_weakpoint_anchor') fail(`boss weakpoint socket binding missing: ${result.state?.bossWeakpointSocketBinding}`);
      if (result.state?.cloudGeometry !== false) fail(`cloud geometry should be disabled, got ${result.state?.cloudGeometry}`);
      if (result.state?.bossArenaAsset !== 'boss_dreadnought_leviathan_glb') fail(`Blender boss arena asset not active: ${result.state?.bossArenaAsset}`);
      if (result.state?.arenaAssetDeckCluster !== true) fail(`Blender arena deck cluster asset not active: ${result.state?.arenaAssetDeckCluster}`);
      if (result.state?.bossEntityType !== 'boss_entity_3d_owns_state_and_geometry') fail(`boss entity regression: ${result.state?.bossEntityType}`);
      if (result.state?.stormOceanTextureAsset !== true) fail(`storm ocean texture asset not active: ${result.state?.stormOceanTextureAsset}`);
      if (result.state?.texturedBlenderAssets !== true) fail(`textured Blender asset pass not active: ${result.state?.texturedBlenderAssets}`);
      if (result.state?.projectileVisualPool !== true) fail(`projectile visual pool not active: ${result.state?.projectileVisualPool}`);
      if (Number(result.state?.projectilePoolCount || 0) < 80) fail(`expected at least 80 pooled projectile visuals, got ${result.state?.projectilePoolCount}`);
      if (result.state?.logicalProjectileManager !== true) fail(`logical projectile manager not active: ${result.state?.logicalProjectileManager}`);
      if (result.state?.projectileDataDriven !== true) fail(`projectile data-driven contract not active: ${result.state?.projectileDataDriven}`);
      if (Number(result.state?.logicalProjectilePool || 0) < 100) fail(`expected logical projectile pool >=100, got ${result.state?.logicalProjectilePool}`);
      if (Number(result.state?.playerProjectilePool || 0) < 48) fail(`expected player projectile pool >=48, got ${result.state?.playerProjectilePool}`);
      if (result.state?.playerProjectileHitModel !== 'boss_entity_query_hit_world_aabb') fail(`player projectile hit model missing: ${result.state?.playerProjectileHitModel}`);
      if (Number(result.state?.playerProjectileHits || 0) < 1) fail(`expected player projectiles to hit boss, got ${result.state?.playerProjectileHits}`);
      if (Number(result.state?.bossFireEventCount || 0) < 1) fail(`boss never fired from a muzzle: ${result.state?.bossFireEventCount}`);
      if (Number(result.state?.bossProjectileHitCount || 0) < 1) fail(`boss never registered a hitbox hit: ${result.state?.bossProjectileHitCount}`);
      if (result.state?.bossPhaseController !== true) fail(`boss phase controller not active: ${result.state?.bossPhaseController}`);
      if (result.state?.bossDamageModel !== 'parts_shield_turret_left_turret_right_core') fail(`boss damage model missing: ${result.state?.bossDamageModel}`);
      if (result.state?.bossWeakPointModel !== 'shield_then_both_turrets_then_core') fail(`boss weak-point model missing: ${result.state?.bossWeakPointModel}`);
      if (result.state?.bossPatternScheduler !== true) fail(`boss pattern scheduler missing: ${result.state?.bossPatternScheduler}`);
      if (result.state?.bossDataDriven !== true) fail(`boss data-driven contract missing: ${result.state?.bossDataDriven}`);
      if (!result.state?.bossAttackPattern) fail('boss attack pattern missing');
      if (!result.state?.bossTargetablePart) fail('boss targetable part missing');
      if (Number(result.state?.bossProjectileHitCount || 0) < 1) fail(`boss did not receive logical projectile hits: ${result.state?.bossProjectileHitCount}`);
      if (Number(result.state?.bossHpRatio || 1) >= 1) fail(`boss hp ratio did not change after logical hits: ${result.state?.bossHpRatio}`);
      if (result.state?.cleanArenaOverlay !== true) fail(`clean arena overlay bridge missing: ${result.state?.cleanArenaOverlay}`);
      if (result.state?.playerScaleMode !== 'phone_readable_small_hitbox') fail(`player scale mode missing: ${result.state?.playerScaleMode}`);
      console.log(`Forward/weather browser QA ok: mode=${result.state.missionMode} camera=${result.state.cameraMode} model=${result.state.playerModel} source=${result.state.playerModelSource} shotDir=${result.state.shotDirectionMode} clean=${result.state.backgroundClutterMode} align=${result.state.playerModelAlignment} hardpoint=${result.state.playerWeaponHardpointBinding}/${result.state.playerShotSpawnOrigin} logical=${result.state.logicalPlayerHardpointBinding}/${result.state.logicalPlayerShotOrigin} vfx=${result.state.socketMuzzleVFX}/${result.state.socketMuzzleVFXCount} arena=${result.state.arenaPhase} composition=pass1_boss_entity weakpoint=${result.state.bossWeakpointSocketBinding}/${result.state.bossWeakpointVisualTarget} boss=${result.state.bossArenaAsset} deckCluster=${result.state.arenaAssetDeckCluster} matte=${result.state.staticMatteBackdrop} oceanTexture=${result.state.stormOceanTextureAsset} texturedAssets=${result.state.texturedBlenderAssets} projectilePool=${result.state.projectileVisualPool}/${result.state.projectilePoolCount} logicPool=${result.state.logicalProjectileManager}/${result.state.logicalProjectilePool} playerPool=${result.state.playerProjectilePool} hits=${result.state.playerProjectileHits} bossPhase=${result.state.bossPhase}/${result.state.bossDamageModel} pattern=${result.state.bossAttackPattern} target=${result.state.bossTargetablePart} cleanOverlay=${result.state.cleanArenaOverlay} clouds=${result.state.cloudGeometry} layers=${result.state.depthLayerCount} wind=${Number(result.state.windDrift).toFixed(2)} visibility=${Number(result.state.rainVisibility).toFixed(2)} progress=${Number(result.state.progress).toFixed(3)} canvas=${result.canvas.width}x${result.canvas.height}`);
    } finally {
      await browser.close();
    }
  } finally {
    serverProcess.kill('SIGTERM');
    if (serverLog.trim()) console.log(serverLog.trim());
  }
}

main().catch((error) => fail(error.stack || error.message));
