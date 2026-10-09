#!/usr/bin/env node
// Pass 1 QA - combat causality and single play plane.
//
// Correction brief, Pass 1 acceptance: the boss is a real entity that owns its
// own HP and phase, every enemy bullet leaves a visible muzzle, every point of
// player damage comes from a bullet that was on screen, the HUD only displays
// state it does not own, and player, enemies and all bullets share one play
// plane with the sea pushed into a non-interactive under-world.
//
// The script drives the real Web export in Chromium, captures five freeze
// frames with their bridge state, and asserts the contract on every frame.
import { existsSync, mkdirSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import chromiumPack, { inflate, setupLambdaEnvironment } from '@sparticuz/chromium';
import { chromium as playwrightChromium } from 'playwright-core';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sparticuzBin = join(root, 'node_modules', '@sparticuz', 'chromium', 'bin');
const port = Number(process.env.QA_PASS1_PORT || 9100 + Math.floor(Math.random() * 400));
const screenshotDir = join(root, 'qa', 'screenshots');
const summaryPath = join(screenshotDir, 'pass1_causality_qa_summary.json');
const FREEZE_FRAMES = 5;

function fail(message) {
  console.error(`Pass 1 causality QA failed: ${message}`);
  process.exit(1);
}

function expect(condition, message) {
  if (!condition) fail(message);
}

function num(value) {
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
    await new Promise((delay) => setTimeout(delay, 250));
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
    args: [...chromiumPack.args, '--no-sandbox', '--disable-dev-shm-usage', '--ignore-gpu-blocklist', '--enable-webgl']
  });
}

async function launchMission(page) {
  await page.goto(`http://127.0.0.1:${port}/index.html`, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForSelector('canvas', { timeout: 60000 });
  await page.waitForFunction(() => !!window.ForceWarBridge, null, { timeout: 60000 });
  await page.click('canvas', { position: { x: 360, y: 640 } });
  await page.waitForTimeout(1600);
  await page.keyboard.press('Space');
  await page.waitForTimeout(900);
  await page.keyboard.press('Space');
  await page.waitForTimeout(700);
  await page.keyboard.press('Space');
}

// ------------------------------------------------------------ contract checks
function assertOwnership(state, frame) {
  expect(state?.screen === 'playing', `[f${frame}] expected playing screen, got ${state?.screen}`);
  expect(state?.missionMode === 'forward_air_combat', `[f${frame}] mission mode regression: ${state?.missionMode}`);
  expect(state?.pass1CausalityContract === 'boss_entity_owns_state_bullets_from_visible_muzzles',
    `[f${frame}] pass 1 causality contract missing: ${state?.pass1CausalityContract}`);
  expect(state?.phase3QAContract === 'pass1_combat_causality_v1', `[f${frame}] QA contract regression: ${state?.phase3QAContract}`);
  expect(state?.foundationCorrectionPass === 'pass_1_combat_causality_and_playfield',
    `[f${frame}] correction pass marker missing: ${state?.foundationCorrectionPass}`);

  // 1. The boss entity owns boss state - not the HUD, not the director.
  expect(state?.bossEntityType === 'boss_entity_3d_owns_state_and_geometry', `[f${frame}] boss entity type: ${state?.bossEntityType}`);
  expect(String(state?.bossStateOwner || '').includes('BossStateStore'), `[f${frame}] boss state owner: ${state?.bossStateOwner}`);
  expect(state?.bossModelLoaded === true, `[f${frame}] boss 3D model not loaded: ${state?.bossModelLoaded}`);
  expect(state?.bossStaticImageEntity === false, `[f${frame}] a static image is still acting as the boss: ${state?.bossStaticImageEntity}`);
  expect(state?.staticMatteBackdrop === false, `[f${frame}] static matte backdrop still instantiated: ${state?.staticMatteBackdrop}`);
  expect(num(state?.bossPartCount) >= 3, `[f${frame}] boss needs core + at least two turrets: ${state?.bossPartCount}`);
  expect(state?.bossHitboxModel === 'per_part_world_aabb_from_visible_geometry', `[f${frame}] boss hitbox model: ${state?.bossHitboxModel}`);
  expect(state?.playerProjectileHitModel === 'boss_entity_query_hit_world_aabb', `[f${frame}] boss hit test is not geometry bound: ${state?.playerProjectileHitModel}`);
  expect(state?.hudValuesHardcoded === false, `[f${frame}] HUD is reporting hard-coded values: ${state?.hudValuesHardcoded}`);
  expect(typeof state?.bossName === 'string' && state.bossName.length > 0, `[f${frame}] HUD boss name not sourced from the entity: ${state?.bossName}`);
}

function assertBulletCausality(state, frame) {
  // 2. Every enemy bullet comes from a boss muzzle fire event.
  expect(state?.enemyBulletSourceModel === 'boss_and_air_enemy_muzzle_fire_events_only',
    `[f${frame}] enemy bullet source model: ${state?.enemyBulletSourceModel}`);
  expect(num(state?.enemyBulletsWithoutVisibleSource) === 0,
    `[f${frame}] bullets exist with no visible shooter: ${state?.enemyBulletsWithoutVisibleSource}`);
  expect(num(state?.decorativeBulletNodes) === 0, `[f${frame}] decorative bullet nodes returned: ${state?.decorativeBulletNodes}`);
  expect(num(state?.unhittableMidfieldEntities) === 0, `[f${frame}] unhittable midfield props returned: ${state?.unhittableMidfieldEntities}`);
  expect(state?.bossProjectileTracking === false, `[f${frame}] enemy bullets are homing: ${state?.bossProjectileTracking}`);
  expect(state?.bossPatternDrivenProjectiles === true, `[f${frame}] enemy fire is not pattern driven: ${state?.bossPatternDrivenProjectiles}`);
  // Three firing parts (two turret batteries plus the core). Destroyed parts
  // must stop firing, so the live muzzle floor drops with them instead of
  // being a fixed number the boss can never satisfy late in the fight.
  const firingParts = Math.max(1, 3 - num(state?.bossDestroyedParts));
  expect(num(state?.bossLiveMuzzleCount) >= firingParts,
    `[f${frame}] live muzzle count too low: ${state?.bossLiveMuzzleCount} with ${state?.bossDestroyedParts} destroyed parts`);
  expect(state?.shotDirectionMode === 'xz_plane_velocity_aligned', `[f${frame}] bullet orientation model: ${state?.shotDirectionMode}`);

  // 3. Player shots leave visible gun points.
  expect(state?.logicalPlayerShotOrigin === 'glb_muzzle_socket', `[f${frame}] player shot origin: ${state?.logicalPlayerShotOrigin}`);
  expect(state?.playerShotVisibleFromSocket === true, `[f${frame}] player muzzle VFX missing: ${state?.playerShotVisibleFromSocket}`);
  // Forward OF THE HULL: the aircraft drifts along the corridor, so the muzzle
  // offset is what must stay negative, not its absolute world Z.
  expect(num(state?.playerMuzzleForwardOffset) < -0.1,
    `[f${frame}] player muzzle is not forward of the hull: ${state?.playerMuzzleForwardOffset}`);

  // 4. Damage in both directions is caused by a bullet that was on screen.
  expect(num(state?.playerDamageEvents) === num(state?.playerDamageEventsWithVisibleSource),
    `[f${frame}] player damage without a visible bullet: ${state?.playerDamageEvents}/${state?.playerDamageEventsWithVisibleSource}`);
  expect(state?.bossImpactFeedbackSource === 'boss_entity_part_hitbox_hits',
    `[f${frame}] boss damage feedback source: ${state?.bossImpactFeedbackSource}`);
}

function assertSinglePlane(state, frame) {
  expect(state?.singlePlayfieldPlane === true, `[f${frame}] play field is not a single plane: ${state?.singlePlayfieldPlane}`);
  expect(state?.projectileSinglePlane === true, `[f${frame}] bullets are off the play plane: ${state?.projectileSinglePlane}`);
  const plane = num(state?.combatPlaneY);
  expect(Math.abs(num(state?.projectilePlaneY) - plane) < 0.001, `[f${frame}] bullet plane != combat plane: ${state?.projectilePlaneY}/${plane}`);
  expect(Math.abs(num(state?.bossPlaneY) - plane) < 0.001, `[f${frame}] boss plane != combat plane: ${state?.bossPlaneY}/${plane}`);
  expect(Math.abs(num(state?.playerPlaneY) - plane) < 0.001, `[f${frame}] player plane != combat plane: ${state?.playerPlaneY}/${plane}`);
  expect(state?.playerOnCombatPlane === true, `[f${frame}] player is not on the combat plane: ${state?.playerOnCombatPlane}`);
  expect(num(state?.underworldY) < plane - 8.0, `[f${frame}] sea layer is not pushed below the play plane: ${state?.underworldY}`);
  expect(state?.playerShadowMarker === true, `[f${frame}] player ground marker missing: ${state?.playerShadowMarker}`);
  expect(state?.playerHitboxMarker === true, `[f${frame}] player hitbox marker missing: ${state?.playerHitboxMarker}`);
  expect(state?.cameraMode === 'chase_behind_above', `[f${frame}] camera mode regression: ${state?.cameraMode}`);
  expect(num(state?.bossWorldZ) < -20.0, `[f${frame}] boss is not in the upper third of the field: ${state?.bossWorldZ}`);
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
      await page.waitForFunction(() => Number(window.ForceWarBridge?.state?.bossFireEventCount || 0) > 0, null, { timeout: 30000 });
      await page.waitForFunction(() => Number(window.ForceWarBridge?.state?.playerProjectileHits || 0) >= 4, null, { timeout: 30000 });

      mkdirSync(screenshotDir, { recursive: true });
      // Five freeze frames, each with the aircraft somewhere else, so the
      // acceptance test is not a single lucky pose.
      const track = [[250, 980], [470, 860], [300, 1050], [520, 960], [360, 900]];
      const frames = [];
      for (let index = 0; index < FREEZE_FRAMES; index += 1) {
        const point = track[index % track.length];
        await page.mouse.move(point[0], point[1]);
        await page.mouse.down();
        await page.waitForTimeout(1500);
        const state = await page.evaluate(() => window.ForceWarBridge?.state || null);
        const framePath = join(screenshotDir, `pass1_causality_frame_${index + 1}.png`);
        await page.screenshot({ path: framePath, fullPage: false });
        await page.mouse.up();
        const bytes = statSync(framePath).size;
        expect(bytes > 120000, `[f${index + 1}] freeze frame looks blank: ${bytes} bytes`);

        assertOwnership(state, index + 1);
        assertBulletCausality(state, index + 1);
        assertSinglePlane(state, index + 1);
        writeFileSync(join(screenshotDir, `pass1_causality_frame_${index + 1}_state.json`), `${JSON.stringify(state, null, 2)}\n`);
        frames.push({
          frame: index + 1,
          screenshot: framePath,
          bytes,
          bossPhase: state.bossPhase,
          bossPhaseName: state.bossPhaseName,
          bossHpRatio: state.bossHpRatio,
          bossTargetablePart: state.bossTargetablePart,
          bossAttackState: state.bossAttackState,
          bossTelegraphPart: state.bossTelegraphPart,
          bossFireEventCount: state.bossFireEventCount,
          bossDestroyedParts: state.bossDestroyedParts,
          activeLogicalProjectiles: state.activeLogicalProjectiles,
          enemyPoolRendered: state.enemyPoolRendered,
          playerPoolRendered: state.playerPoolRendered,
          playerProjectileHits: state.playerProjectileHits,
          playerDamageEvents: state.playerDamageEvents,
          playerDamageEventsWithVisibleSource: state.playerDamageEventsWithVisibleSource,
          hp: state.hp,
          shield: state.shield,
          score: state.score
        });
      }

      const last = frames[frames.length - 1];
      const first = frames[0];
      // 5. Boss HP only moves because player bullets struck a part.
      expect(num(last.playerProjectileHits) > num(first.playerProjectileHits),
        `player hits did not accumulate across freeze frames: ${first.playerProjectileHits} -> ${last.playerProjectileHits}`);
      const finalState = await page.evaluate(() => window.ForceWarBridge?.state || null);
      expect(num(finalState?.bossHpRatio) < 1.0, `boss HP never moved: ${finalState?.bossHpRatio}`);
      expect(num(finalState?.bossWeakpointDamageEvents) > 0, `no weak point damage events: ${finalState?.bossWeakpointDamageEvents}`);
      expect(num(finalState?.bossTelegraphEvents) > 0, `no telegraph before heavy attacks: ${finalState?.bossTelegraphEvents}`);
      // Any destroyed part must have stopped firing: live muzzles shrink with parts.
      const destroyed = Array.isArray(finalState?.bossDestroyedPartList) ? finalState.bossDestroyedPartList : [];
      if (destroyed.includes('turret_left') || destroyed.includes('turret_right')) {
        expect(num(finalState?.bossLiveMuzzleCount) < 5, `destroyed turret still exposes its muzzles: ${finalState?.bossLiveMuzzleCount}`);
      }
      if (pageErrors.length > 0) fail(`browser page errors: ${pageErrors.join(' | ')}`);

      const summary = {
        passed: true,
        qa: 'pass1_combat_causality_v1',
        generatedAt: new Date().toISOString(),
        engine: 'Godot 4.6.2.stable - gl_compatibility - Web export',
        frames,
        final: {
          bossHpRatio: finalState.bossHpRatio,
          bossPhase: finalState.bossPhase,
          bossPhaseName: finalState.bossPhaseName,
          bossDestroyedPartList: destroyed,
          bossWeakpointDamageEvents: finalState.bossWeakpointDamageEvents,
          bossTelegraphEvents: finalState.bossTelegraphEvents,
          bossLiveMuzzleCount: finalState.bossLiveMuzzleCount,
          playerDamageEvents: finalState.playerDamageEvents,
          playerDamageEventsWithVisibleSource: finalState.playerDamageEventsWithVisibleSource
        }
      };
      writeFileSync(summaryPath, `${JSON.stringify(summary, null, 2)}\n`);
      console.log(`Pass 1 causality QA ok: frames=${frames.length} bossHp=${finalState.bossHpRatio} phase=${finalState.bossPhase}/${finalState.bossPhaseName} hits=${finalState.playerProjectileHits} telegraphs=${finalState.bossTelegraphEvents} playerDamage=${finalState.playerDamageEvents}/${finalState.playerDamageEventsWithVisibleSource} summary=${summaryPath}`);
    } finally {
      await browser.close();
    }
  } finally {
    serverProcess.kill('SIGTERM');
    if (serverLog.trim()) console.log(serverLog.trim());
  }
}

main().catch((error) => fail(error.stack || error.message));
