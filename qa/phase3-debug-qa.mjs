#!/usr/bin/env node
import { existsSync, mkdirSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import chromiumPack, { inflate, setupLambdaEnvironment } from '@sparticuz/chromium';
import { chromium as playwrightChromium } from 'playwright-core';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sparticuzBin = join(root, 'node_modules', '@sparticuz', 'chromium', 'bin');
const port = Number(process.env.QA_PHASE3_PORT || 9100 + Math.floor(Math.random() * 400));
const screenshotDir = join(root, 'qa', 'screenshots');
const screenshotPath = join(screenshotDir, 'phase3_debug_qa_final.png');
const statePath = join(screenshotDir, 'phase3_debug_qa_final_state.json');
const summaryPath = join(screenshotDir, 'phase3_debug_qa_final_summary.json');

function fail(message) {
  console.error(`Phase 3 debug QA failed: ${message}`);
  process.exit(1);
}

function expect(condition, message) {
  if (!condition) fail(message);
}

function numberValue(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
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

async function launchMission(page) {
  await page.goto(`http://127.0.0.1:${port}/index.html`, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForSelector('canvas', { timeout: 60000 });
  await page.waitForFunction(() => !!window.ForceWarBridge, null, { timeout: 60000 });
  await page.click('canvas', { position: { x: 360, y: 640 } });

  // Loading page must remain visible long enough for branded boot QA, then the
  // keyboard path enters title -> briefing -> direct forward-air gameplay.
  await page.waitForTimeout(1600);
  await page.keyboard.press('Space');
  await page.waitForTimeout(900);
  await page.keyboard.press('Space');
  await page.waitForTimeout(700);
  await page.keyboard.press('Space');
}

function assertPhase3State(state) {
  expect(state?.screen === 'playing', `expected active playing screen, got ${state?.screen}`);
  expect(state?.missionMode === 'forward_air_combat', `mission mode regression: ${state?.missionMode}`);
  expect(state?.cameraMode === 'chase_behind_above', `camera mode regression: ${state?.cameraMode}`);
  expect(state?.shotDirectionMode === 'forward_depth_negative_z', `player shot direction regression: ${state?.shotDirectionMode}`);
  expect(state?.shotVisualOrientation === 'forward_aligned_xz_not_billboard_vertical', `shot visual orientation regression: ${state?.shotVisualOrientation}`);
  expect(state?.legacyVerticalShotColumns === false, `legacy vertical shot columns returned: ${state?.legacyVerticalShotColumns}`);
  expect(numberValue(state?.legacyNearCameraCyanPulseNodes) === 0, `legacy near-camera cyan pulse nodes should be disabled: ${state?.legacyNearCameraCyanPulseNodes}`);
  expect(state?.rainGeometryMode === 'haze_only_no_vertical_columns', `rain geometry mode can read as vertical columns: ${state?.rainGeometryMode}`);
  expect(numberValue(state?.nearRainSheetCount) === 0, `near rain sheets should be disabled for clean Phase 3 debug capture: ${state?.nearRainSheetCount}`);
  expect(state?.cloudGeometry === false, `cloud geometry should stay disabled in forward reference composition: ${state?.cloudGeometry}`);
  expect(state?.backgroundClutterMode === 'foundation_clean', `background clutter mode regression: ${state?.backgroundClutterMode}`);
  expect(state?.cleanArenaOverlay === true, `clean arena overlay missing: ${state?.cleanArenaOverlay}`);

  expect(state?.phase3GameplayVFXPass === 'boss_weakpoint_hit_feedback', `phase 3 gameplay VFX pass missing: ${state?.phase3GameplayVFXPass}`);
  expect(state?.phase3DebugStatus === 'boss_weakpoint_muzzle_fire_debug_locked', `phase 3 debug status not locked: ${state?.phase3DebugStatus}`);
  expect(state?.phase3QAContract === 'phase3_debug_browser_v1', `phase 3 QA contract missing: ${state?.phase3QAContract}`);
  expect(state?.phase3VisualSafety === 'clean_hud_no_vertical_columns_no_cloud_geometry', `phase 3 visual safety missing: ${state?.phase3VisualSafety}`);
  expect(state?.phase3BossCombatChunk === 'destructible_hardpoint_phase_transition', `phase 3 boss combat chunk missing: ${state?.phase3BossCombatChunk}`);

  expect(state?.bossArenaAsset === 'boss_dreadnought_leviathan_glb', `boss GLB asset missing: ${state?.bossArenaAsset}`);
  expect(state?.bossWeakpointSocketBinding === 'glb_boss_socket_runtime', `boss weakpoint socket binding missing: ${state?.bossWeakpointSocketBinding}`);
  expect(state?.bossGLBWeakpointSocketFound === true, `boss weakpoint socket not found: ${state?.bossGLBWeakpointSocketFound}`);
  expect(state?.bossWeakpointVisual === true, `boss weakpoint visual missing: ${state?.bossWeakpointVisual}`);
  expect(numberValue(state?.bossWeakpointWorldZ) < -30, `boss weakpoint is not in forward depth: ${state?.bossWeakpointWorldZ}`);
  expect(state?.bossImpactFeedbackSource === 'logical_player_projectile_hits', `boss impact source regression: ${state?.bossImpactFeedbackSource}`);
  expect(state?.bossDamageFeedbackMode === 'pooled_sprite_impacts_target_reticle', `boss damage feedback mode regression: ${state?.bossDamageFeedbackMode}`);
  expect(numberValue(state?.bossImpactVFXPool) >= 8, `boss impact pool too small: ${state?.bossImpactVFXPool}`);
  expect(numberValue(state?.bossImpactEvents) >= 6, `boss impact events too low: ${state?.bossImpactEvents}`);
  expect(state?.bossImpactVFXActive === true, `boss impact VFX not active in capture window: ${state?.bossImpactVFXActive}`);
  expect(numberValue(state?.bossWeakpointDamageMultiplier) > 1.0, `weakpoint damage multiplier missing: ${state?.bossWeakpointDamageMultiplier}`);
  expect(numberValue(state?.bossExposedCoreDamageMultiplier) > 1.0, `exposed core damage multiplier missing: ${state?.bossExposedCoreDamageMultiplier}`);
  expect(numberValue(state?.bossExposedCoreDamageMultiplier) < numberValue(state?.bossWeakpointDamageMultiplier), `core damage should be paced slower than shield/turret break: ${state?.bossExposedCoreDamageMultiplier}/${state?.bossWeakpointDamageMultiplier}`);
  expect(numberValue(state?.bossWeakpointDamageEvents) >= 8, `weakpoint damage events too low: ${state?.bossWeakpointDamageEvents}`);
  expect(numberValue(state?.bossPhase) === 3, `boss should be captured in core-exposed phase, got: ${state?.bossPhase}/${state?.bossPhaseName}`);
  expect(numberValue(state?.bossCoreRatio) > 0.05, `boss core should be exposed but not instantly defeated in proof capture: ${state?.bossCoreRatio}`);
  expect(numberValue(state?.bossPhaseTransitionCount) >= 2, `boss phase transition events too low: ${state?.bossPhaseTransitionCount}`);
  expect(state?.bossPhaseTransitionLocked === true, `boss phase transition lock missing: ${state?.bossPhaseTransitionLocked}`);
  expect(numberValue(state?.bossPartDestructionEvents) >= 2, `boss part destruction events too low: ${state?.bossPartDestructionEvents}`);
  expect(numberValue(state?.bossPartDestructionEventsSeen) >= 2, `arena did not observe boss part destruction chain: ${state?.bossPartDestructionEventsSeen}`);
  expect(numberValue(state?.bossPhaseTransitionEventsSeen) >= 2, `arena did not observe phase transition chain: ${state?.bossPhaseTransitionEventsSeen}`);
  expect(numberValue(state?.bossShieldRatio) <= 0.01, `boss shield was not destroyed: ${state?.bossShieldRatio}`);
  expect(numberValue(state?.bossTurretRatio) <= 0.01, `boss turret hardpoint was not destroyed: ${state?.bossTurretRatio}`);
  expect(state?.bossLatestDestroyedPart, `latest destroyed boss part missing: ${state?.bossLatestDestroyedPart}`);
  const destroyedParts = Array.isArray(state?.bossDestroyedPartList) ? state.bossDestroyedPartList : [];
  expect(destroyedParts.includes('shield'), `shield destruction missing from destroyed part list: ${JSON.stringify(destroyedParts)}`);
  expect(destroyedParts.includes('turrets'), `turret destruction missing from destroyed part list: ${JSON.stringify(destroyedParts)}`);
  expect(state?.bossPartDamageVFX === 'socket_part_damage_markers', `boss part damage VFX mode missing: ${state?.bossPartDamageVFX}`);
  expect(state?.bossDestroyedPartVFXActive === true, `destroyed part VFX inactive: ${state?.bossDestroyedPartVFXActive}`);
  expect(numberValue(state?.bossDestroyedPartVFXCount) >= 2, `destroyed part VFX count too low: ${state?.bossDestroyedPartVFXCount}`);
  expect(state?.bossTargetablePart === 'core', `boss target did not move to exposed core: ${state?.bossTargetablePart}`);

  expect(state?.bossMuzzleSocketBinding === 'glb_boss_muzzle_socket_runtime', `boss muzzle socket binding missing: ${state?.bossMuzzleSocketBinding}`);
  expect(state?.bossGLBMuzzleSocketsFound === true, `boss muzzle sockets not found: ${state?.bossGLBMuzzleSocketsFound}`);
  expect(numberValue(state?.bossMuzzleSocketCount) >= 3, `boss muzzle socket count too low: ${state?.bossMuzzleSocketCount}`);
  const muzzleNames = Array.isArray(state?.bossMuzzleSocketNames) ? state.bossMuzzleSocketNames : [];
  for (const requiredName of ['Boss_Muzzle_Left', 'Boss_Muzzle_Core', 'Boss_Muzzle_Right']) {
    expect(muzzleNames.includes(requiredName), `missing boss muzzle socket name ${requiredName}: ${JSON.stringify(muzzleNames)}`);
  }
  expect(numberValue(state?.bossMuzzleSpreadX) > 1.0, `boss muzzle spread did not validate left/right sockets: ${state?.bossMuzzleSpreadX}`);
  expect(state?.bossSocketFireVFX === 'glb_boss_muzzle_forward_lanes', `boss socket fire VFX mode missing: ${state?.bossSocketFireVFX}`);
  expect(state?.bossSocketFireDepthMode === 'forward_lanes_positive_z_to_player', `boss socket fire depth mode regression: ${state?.bossSocketFireDepthMode}`);
  expect(state?.bossSocketFireVFXActive === true, `boss socket fire VFX inactive: ${state?.bossSocketFireVFXActive}`);
  expect(numberValue(state?.bossSocketFireVFXCount) >= 3, `boss socket fire VFX count too low: ${state?.bossSocketFireVFXCount}`);
  expect(numberValue(state?.bossSocketFireEvents) >= 8, `boss socket fire events too low: ${state?.bossSocketFireEvents}`);
  expect(state?.bossHardpointFireNonHoming === true, `boss hardpoint fire is not explicitly non-homing: ${state?.bossHardpointFireNonHoming}`);

  expect(state?.logicalProjectileManager === true, `logical projectile manager missing: ${state?.logicalProjectileManager}`);
  expect(state?.projectileCollisionMode === 'pooled_logical_radius_no_physics_body', `projectile collision mode regression: ${state?.projectileCollisionMode}`);
  expect(state?.phase3ProjectileDebugStatus === 'boss_socket_forward_fire_non_homing', `projectile debug status not locked: ${state?.phase3ProjectileDebugStatus}`);
  expect(state?.bossProjectileAimingModel === 'non_homing_forward_depth_lanes', `boss projectile aiming model regression: ${state?.bossProjectileAimingModel}`);
  expect(state?.bossProjectileTracking === false, `boss projectile tracking should be false: ${state?.bossProjectileTracking}`);
  expect(state?.bossProjectileVelocityMode === 'positive_z_no_player_tracking', `boss projectile velocity mode regression: ${state?.bossProjectileVelocityMode}`);
  expect(state?.playerProjectileVelocityMode === 'negative_z_socket_origin', `player projectile velocity mode regression: ${state?.playerProjectileVelocityMode}`);
  expect(state?.logicalBossProjectileOrigin === 'glb_boss_muzzle_socket', `logical boss projectile origin not socket-bound: ${state?.logicalBossProjectileOrigin}`);
  expect(numberValue(state?.logicalBossMuzzleSocketSpawns) >= 8, `logical boss muzzle socket spawns too low: ${state?.logicalBossMuzzleSocketSpawns}`);
  expect(numberValue(state?.logicalBossMuzzleSocketCount) >= 3, `logical boss muzzle socket count too low: ${state?.logicalBossMuzzleSocketCount}`);
  expect(numberValue(state?.activeLogicalProjectiles) > 0, `no active boss logical projectiles: ${state?.activeLogicalProjectiles}`);

  expect(state?.playerWeaponHardpointBinding === 'glb_socket_runtime', `player hardpoint binding regression: ${state?.playerWeaponHardpointBinding}`);
  expect(state?.logicalPlayerShotOrigin === 'glb_muzzle_socket', `logical player shot origin regression: ${state?.logicalPlayerShotOrigin}`);
  expect(numberValue(state?.playerMuzzleCenterZ) < -0.1, `player muzzle center no longer in forward -Z: ${state?.playerMuzzleCenterZ}`);
  expect(state?.playerMuzzleForwardZLocked === true, `player muzzle forward lock missing: ${state?.playerMuzzleForwardZLocked}`);
  expect(numberValue(state?.activePlayerProjectiles) > 0, `no active player logical projectiles: ${state?.activePlayerProjectiles}`);
  expect(numberValue(state?.playerProjectileHits) >= 6, `player projectile hits too low: ${state?.playerProjectileHits}`);
  expect(numberValue(state?.bossHpRatio) < 0.99, `boss HP did not move after hit QA: ${state?.bossHpRatio}`);

  expect(state?.visualLockComposition === 'dreadnought_forward_battle', `visual composition regression: ${state?.visualLockComposition}`);
  expect(state?.projectileVisualPool === true, `projectile visual pool missing: ${state?.projectileVisualPool}`);
  expect(numberValue(state?.projectilePoolCount) >= 80, `projectile visual pool too small: ${state?.projectilePoolCount}`);
  expect(state?.texturedBlenderAssets === true, `textured Blender asset gate failed: ${state?.texturedBlenderAssets}`);
  expect(state?.arenaAssetDeckCluster === true, `arena deck cluster missing: ${state?.arenaAssetDeckCluster}`);
  expect(state?.stormOceanTextureAsset === true, `storm ocean texture missing: ${state?.stormOceanTextureAsset}`);
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
      await launchMission(page);
      await page.waitForFunction(() => window.ForceWarBridge?.state?.missionMode === 'forward_air_combat', null, { timeout: 30000 });
      await page.waitForFunction(() => window.ForceWarBridge?.state?.phase3DebugStatus === 'boss_weakpoint_muzzle_fire_debug_locked', null, { timeout: 25000 });
      await page.waitForFunction(() => window.ForceWarBridge?.state?.phase3ProjectileDebugStatus === 'boss_socket_forward_fire_non_homing', null, { timeout: 15000 });
      await page.waitForFunction(() => Number(window.ForceWarBridge?.state?.bossImpactEvents || 0) >= 6, null, { timeout: 15000 });
      await page.waitForFunction(() => Number(window.ForceWarBridge?.state?.logicalBossMuzzleSocketSpawns || 0) >= 8, null, { timeout: 15000 });
      await page.waitForFunction(() => Number(window.ForceWarBridge?.state?.bossPhase || 1) >= 3, null, { timeout: 45000 });
      await page.waitForFunction(() => Number(window.ForceWarBridge?.state?.bossPhaseTransitionCount || 0) >= 2, null, { timeout: 10000 });
      await page.waitForFunction(() => Number(window.ForceWarBridge?.state?.bossPartDestructionEvents || 0) >= 2, null, { timeout: 10000 });
      await page.waitForFunction(() => window.ForceWarBridge?.state?.bossTargetablePart === 'core', null, { timeout: 10000 });
      await page.waitForFunction(() => window.ForceWarBridge?.state?.bossDestroyedPartVFXActive === true, null, { timeout: 10000 });
      await page.waitForFunction(() => Number(window.ForceWarBridge?.state?.bossCoreRatio || 0) > 0.05, null, { timeout: 10000 });
      await page.waitForTimeout(80);

      const result = await page.evaluate(() => {
        const canvas = document.querySelector('canvas');
        return {
          state: window.ForceWarBridge?.state || null,
          eventsSeen: Array.isArray(window.ForceWarBridge?.events) ? window.ForceWarBridge.events.length : 0,
          lastEvent: window.ForceWarBridge?.lastEvent || null,
          canvas: canvas ? { width: canvas.width, height: canvas.height } : null
        };
      });
      if (pageErrors.length > 0) fail(`browser page errors: ${pageErrors.join(' | ')}`);
      expect(result.canvas?.width === 720 && result.canvas?.height === 1280, `expected 720x1280 canvas, got ${result.canvas?.width}x${result.canvas?.height}`);
      assertPhase3State(result.state);

      mkdirSync(screenshotDir, { recursive: true });
      await page.screenshot({ path: screenshotPath, fullPage: false });
      const shotSize = statSync(screenshotPath).size;
      expect(shotSize > 200000, `phase 3 screenshot appears too small/blank: ${shotSize} bytes`);

      const summary = {
        passed: true,
        qa: 'phase3_debug_browser_v1',
        generatedAt: new Date().toISOString(),
        canvas: result.canvas,
        screenshot: screenshotPath,
        state: statePath,
        metrics: {
          phase3DebugStatus: result.state.phase3DebugStatus,
          phase3BossCombatChunk: result.state.phase3BossCombatChunk,
          bossPhase: result.state.bossPhase,
          bossPhaseName: result.state.bossPhaseName,
          bossPhaseTransitionCount: result.state.bossPhaseTransitionCount,
          bossTargetablePart: result.state.bossTargetablePart,
          bossDestroyedParts: result.state.bossDestroyedParts,
          bossLatestDestroyedPart: result.state.bossLatestDestroyedPart,
          bossDestroyedPartVFXCount: result.state.bossDestroyedPartVFXCount,
          bossWeakpointDamageEvents: result.state.bossWeakpointDamageEvents,
          bossExposedCoreDamageMultiplier: result.state.bossExposedCoreDamageMultiplier,
          bossCoreRatio: result.state.bossCoreRatio,
          bossMuzzleSocketBinding: result.state.bossMuzzleSocketBinding,
          bossMuzzleSocketCount: result.state.bossMuzzleSocketCount,
          bossMuzzleSpreadX: result.state.bossMuzzleSpreadX,
          bossSocketFireEvents: result.state.bossSocketFireEvents,
          logicalBossProjectileOrigin: result.state.logicalBossProjectileOrigin,
          logicalBossMuzzleSocketSpawns: result.state.logicalBossMuzzleSocketSpawns,
          bossImpactEvents: result.state.bossImpactEvents,
          playerProjectileHits: result.state.playerProjectileHits,
          bossHpRatio: result.state.bossHpRatio,
          eventsSeen: result.eventsSeen,
          screenshotBytes: shotSize
        }
      };
      writeFileSync(statePath, `${JSON.stringify(result.state, null, 2)}\n`);
      writeFileSync(summaryPath, `${JSON.stringify(summary, null, 2)}\n`);
      console.log(`Phase 3 debug QA ok: screenshot=${screenshotPath} state=${statePath} phase=${result.state.bossPhase}/${result.state.bossPhaseName} target=${result.state.bossTargetablePart} destroyed=${result.state.bossDestroyedParts}/${result.state.bossLatestDestroyedPart} bossFire=${result.state.bossMuzzleSocketBinding}/${result.state.bossSocketFireEvents} logical=${result.state.logicalBossProjectileOrigin}/${result.state.logicalBossMuzzleSocketSpawns} impacts=${result.state.bossImpactEvents} hits=${result.state.playerProjectileHits} canvas=${result.canvas.width}x${result.canvas.height}`);
    } finally {
      await browser.close();
    }
  } finally {
    serverProcess.kill('SIGTERM');
    if (serverLog.trim()) console.log(serverLog.trim());
  }
}

main().catch((error) => fail(error.stack || error.message));
