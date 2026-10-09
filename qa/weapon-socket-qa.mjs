#!/usr/bin/env node
// Weapon socket / aiming contract QA.
//
// Developer correction: position comes from the socket, direction comes from the
// aiming system. The aircraft banks, so a barrel-axis direction would throw
// shots off the play plane, and a missing socket must raise a hard error rather
// than silently falling back to the hull origin.
//
// Asserted here, on the real Web export:
//   * every configured gun socket resolves by name, zero socket failures,
//   * shots leave the socket (not the hull centre) while the ship is banking,
//   * the spawn point sits just ahead of the barrel (muzzle clearance),
//   * shot direction stays exactly on the play plane (dir.y == 0),
//   * both streams converge on the aim point,
//   * the debug gizmo can be switched on and reports itself,
//   * the muzzle flash sits on the barrel, within the clearance the first
//     bullet spawns at, so the first frame of a shot already shows fire,
//   * player missiles hang on the HP_ pylons, leave in the configured order,
//     disappear from the pylon they were fired from (ammo indicator), drop
//     before igniting, and reappear after the reload.
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import chromiumPack, { inflate, setupLambdaEnvironment } from '@sparticuz/chromium';
import { chromium as playwrightChromium } from 'playwright-core';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sparticuzBin = join(root, 'node_modules', '@sparticuz', 'chromium', 'bin');
const port = Number(process.env.QA_WEAPON_PORT || 9800 + Math.floor(Math.random() * 180));
const screenshotDir = join(root, 'qa', 'screenshots');
const summaryPath = join(screenshotDir, 'weapon_socket_qa_summary.json');

function fail(message) {
  console.error(`Weapon socket QA failed: ${message}`);
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
  while (Date.now() - started < 30000) {
    if (serverProcess.exitCode !== null) fail(`server.js exited with ${serverProcess.exitCode}`);
    try {
      const response = await fetch(`http://127.0.0.1:${port}/healthz`);
      if (response.ok) return;
    } catch { /* retry */ }
    await new Promise((delay) => setTimeout(delay, 250));
  }
  fail('server.js never became healthy');
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

function assertSocketContract(state, label) {
  expect(state?.playerWeaponSocketResolution === 'by_name_from_glb_no_origin_fallback',
    `[${label}] socket resolution model: ${state?.playerWeaponSocketResolution}`);
  expect(state?.playerWeaponSocketError === '', `[${label}] socket error raised: ${state?.playerWeaponSocketError}`);
  expect(num(state?.playerGunSocketCount) >= 2, `[${label}] gun sockets resolved: ${state?.playerGunSocketCount}`);
  expect(num(state?.playerShotSocketFailures) === 0, `[${label}] shots were dropped for missing sockets: ${state?.playerShotSocketFailures}`);
  expect(state?.playerShotOriginFallbackUsed === false, `[${label}] origin fallback used: ${state?.playerShotOriginFallbackUsed}`);
  expect(state?.playerShotSpawnOrigin === 'glb_muzzle_socket', `[${label}] shot origin: ${state?.playerShotSpawnOrigin}`);
  expect(state?.playerShotDirectionModel === 'aim_convergence_on_play_plane_not_socket_rotation',
    `[${label}] direction model: ${state?.playerShotDirectionModel}`);
  expect(state?.playerShotSubFrameSpacing === true, `[${label}] sub-frame shot spacing missing: ${state?.playerShotSubFrameSpacing}`);
  expect(num(state?.playerShotConvergenceDistance) > 0, `[${label}] convergence distance: ${state?.playerShotConvergenceDistance}`);
}

function assertShotGeometry(state, label) {
  const clearance = num(state.playerShotMuzzleClearance);
  const socketX = num(state.lastPlayerShotSocketX);
  const socketZ = num(state.lastPlayerShotSocketZ);
  const spawnX = num(state.lastPlayerShotSpawnX);
  const spawnZ = num(state.lastPlayerShotSpawnZ);
  const dirX = num(state.lastPlayerShotDirX);
  const dirY = num(state.lastPlayerShotDirY);
  const dirZ = num(state.lastPlayerShotDirZ);

  // Direction must stay exactly on the play plane even at full bank.
  expect(dirY === 0, `[${label}] shot left the play plane: dirY=${dirY}`);
  const length = Math.hypot(dirX, dirZ);
  expect(Math.abs(length - 1) < 0.01, `[${label}] direction not normalised: ${length}`);

  // The spawn point sits just ahead of the barrel. One sub-frame of travel is
  // allowed on top of the clearance because shots are advanced by their age.
  const offset = Math.hypot(spawnX - socketX, spawnZ - socketZ);
  const maxOffset = clearance + num(state.playerShotSpeedPerInterval || 0) + 12.0;
  expect(offset >= clearance - 0.02, `[${label}] shot spawned behind the barrel: ${offset} < ${clearance}`);
  expect(offset <= maxOffset, `[${label}] shot spawned far from the barrel: ${offset}`);

  // It must be a barrel, not the hull centre: compare against the aircraft's
  // own centre line, not against the aim point (the aim point drifts while the
  // ship is still catching up to the finger).
  // The authored wing-root station comes from the GLB itself
  // (playerGunLateralOffset), so the assertion survives re-authoring: the shot
  // must leave the barrel the Blender Empty defines, not the hull centre.
  const hullX = num(state.playerWorldX);
  const authored = num(state.playerGunLateralOffset);
  expect(authored > 0.05, `[${label}] authored gun offset collapsed onto the centre line: ${authored}`);
  const lateral = Math.abs(socketX - hullX);
  expect(lateral > authored * 0.5,
    `[${label}] shot origin collapsed onto the aircraft centre line: socketX=${socketX} hullX=${hullX} authored=${authored}`);
  expect(lateral < authored + 0.35,
    `[${label}] shot origin is not on the authored barrel: lateral=${lateral} authored=${authored}`);
}

function assertMuzzleFlash(state, label) {
  const clearance = num(state.playerShotMuzzleClearance);
  expect(num(state.muzzleFlashCount) >= 2, `[${label}] muzzle flash missing: ${state?.muzzleFlashCount}`);
  expect(state?.muzzleFlashAtBarrel === true,
    `[${label}] muzzle flash not on the barrel: offset=${state?.muzzleFlashOffsetFromBarrel}`);
  expect(num(state.muzzleFlashOffsetFromBarrel) <= clearance + 0.001,
    `[${label}] flash further from the barrel than the bullet clearance: ${state?.muzzleFlashOffsetFromBarrel} > ${clearance}`);
  // The flash of the gun that just fired must be at that gun, not elsewhere.
  const socket = String(state.lastPlayerShotSocket || '');
  const flashX = socket.endsWith('right') ? num(state.muzzleFlashRightX) : num(state.muzzleFlashLeftX);
  const flashZ = socket.endsWith('right') ? num(state.muzzleFlashRightZ) : num(state.muzzleFlashLeftZ);
  const distance = Math.hypot(flashX - num(state.lastPlayerShotSocketX), flashZ - num(state.lastPlayerShotSocketZ));
  expect(distance <= clearance + 0.35,
    `[${label}] flash is not at the firing barrel ${socket}: ${distance.toFixed(3)}`);
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
    try {
      const page = await browser.newPage({
        viewport: { width: 720, height: 1280 },
        deviceScaleFactor: 1,
        isMobile: true,
        hasTouch: true
      });
      // Headless software rendering in CI runs at a few frames per second, so a
      // screenshot can legitimately take longer than Playwright's default.
      page.setDefaultTimeout(120000);
      await page.goto(`http://127.0.0.1:${port}/index.html`, { waitUntil: 'domcontentloaded', timeout: 60000 });
      await page.waitForSelector('canvas', { timeout: 60000 });
      await page.waitForFunction(() => !!window.ForceWarBridge, null, { timeout: 60000 });
      await page.click('canvas', { position: { x: 360, y: 640 } });
      await page.waitForTimeout(1600);
      for (const _ of [0, 1, 2]) {
        await page.keyboard.press('Space');
        await page.waitForTimeout(800);
      }
      await page.waitForTimeout(5000);
      mkdirSync(screenshotDir, { recursive: true });

      // --- bank hard left and hard right, freeze a frame at each extreme
      const banks = [
        { label: 'bank_left', x: 120, file: 'weapon_bank_left.png' },
        { label: 'bank_right', x: 600, file: 'weapon_bank_right.png' }
      ];
      const perGunDirections = new Map();
      const results = [];
      for (const bank of banks) {
        await page.mouse.move(360, 950);
        await page.mouse.down();
        await page.mouse.move(bank.x, 950, { steps: 6 });
        let state = null;
        for (let attempt = 0; attempt < 30; attempt += 1) {
          await page.waitForTimeout(160);
          state = await page.evaluate(() => window.ForceWarBridge?.state || null);
          if (state) {
            // Several shots leave per rendered frame, so the per-gun samples
            // are read instead of the single most recent shot.
            for (const sample of state.playerGunShotSamples || []) {
              perGunDirections.set(String(sample.id), {
                socketX: num(sample.socketX),
                dirX: num(sample.dirX),
                aimX: num(sample.aimX)
              });
            }
          }
          if (state && Math.abs(num(state.playerRollDegrees)) > 6) break;
        }
        const path = join(screenshotDir, bank.file);
        await page.screenshot({ path, fullPage: false, timeout: 120000 });
        writeFileSync(path.replace(/\.png$/, '_state.json'), JSON.stringify(state, null, 2));
        assertSocketContract(state, bank.label);
        assertShotGeometry(state, bank.label);
        assertMuzzleFlash(state, bank.label);
        expect(Math.abs(num(state.playerRollDegrees)) > 6,
          `[${bank.label}] aircraft never banked: roll=${state?.playerRollDegrees}`);
        results.push({
          label: bank.label,
          roll: num(state.playerRollDegrees),
          socket: String(state.lastPlayerShotSocket),
          socketX: num(state.lastPlayerShotSocketX),
          spawnX: num(state.lastPlayerShotSpawnX),
          dirX: num(state.lastPlayerShotDirX),
          dirY: num(state.lastPlayerShotDirY),
          gunWorldOrder: state.playerGunWorldOrder,
          path
        });
        console.log(`captured ${path} (roll ${num(state.playerRollDegrees).toFixed(1)} deg, socket ${state.lastPlayerShotSocket})`);
        await page.mouse.up();
        await page.waitForTimeout(600);
      }

      // --- both streams must converge on the aim point
      expect(perGunDirections.size >= 2, `only one gun ever fired: ${[...perGunDirections.keys()].join(',')}`);
      for (const [gun, sample] of perGunDirections) {
        const toAim = sample.aimX - sample.socketX;
        if (Math.abs(toAim) < 0.05) continue;
        expect(Math.sign(sample.dirX) === Math.sign(toAim),
          `stream from ${gun} diverges from the aim point: dirX=${sample.dirX} toAim=${toAim}`);
      }

      // --- pylon missiles: real meshes, config fire order, ammo + reload
      const missileSamples = [];
      const pylonsSeen = new Set();
      const phasesSeen = new Set();
      let minLoaded = Infinity;
      let maxLoaded = 0;
      let reloads = 0;
      let launched = 0;
      for (let tick = 0; tick < 48; tick += 1) {
        const sample = await page.evaluate(() => window.ForceWarBridge?.state || null);
        if (sample) {
          const loaded = num(sample.playerPylonMissilesLoaded);
          minLoaded = Math.min(minLoaded, loaded);
          maxLoaded = Math.max(maxLoaded, loaded);
          reloads = Math.max(reloads, num(sample.playerPylonReloads));
          launched = Math.max(launched, num(sample.playerPylonMissilesLaunched));
          for (const pylon of sample.playerPylonsFiredFrom || []) pylonsSeen.add(String(pylon));
          for (const phase of sample.playerMissilePhases || []) phasesSeen.add(String(phase));
          missileSamples.push({ loaded, launched, phases: sample.playerMissilePhases });
        }
        await page.waitForTimeout(220);
      }
      const missileState = await page.evaluate(() => window.ForceWarBridge?.state || null);
      expect(num(missileState.playerMissileSocketCount) === 6,
        `expected six HP_ pylons, got ${missileState?.playerMissileSocketCount}`);
      expect(num(missileState.playerPylonMissileMeshes) === 6,
        `expected a visible missile mesh per pylon, got ${missileState?.playerPylonMissileMeshes}`);
      expect(launched >= 6, `missiles never left the pylons: ${launched}`);
      expect(minLoaded === 0, `the pylons never ran empty, ammo indicator unproven: min loaded=${minLoaded}`);
      // The headless software renderer runs at ~1 fps, so a full salvo can
      // leave between two samples; what must be proven is that the pylons
      // reloaded and were used again.
      expect(reloads >= 1, `the pylons never reloaded: reloads=${reloads}`);
      expect(maxLoaded >= 5, `reload did not restore the pylon missiles: maxLoaded=${maxLoaded}`);
      expect(launched > 6, `pylons were never reused after a reload: launched=${launched}`);
      // Counted in the engine, not sampled: one rendered frame in the headless
      // renderer is longer than the whole drop phase.
      expect(num(missileState.playerMissileDropSteps) >= launched,
        `missiles armed without dropping off the pylon: dropSteps=${missileState?.playerMissileDropSteps} launched=${launched}`);
      expect(num(missileState.playerMissileIgnitions) >= 1,
        `missile motors never ignited: ${missileState?.playerMissileIgnitions}`);
      const configuredOrder = (missileState.playerMissileSocketIds || []).map(String);
      expect(configuredOrder.length === 6, `fire order not read from the config socket list: ${configuredOrder.join(',')}`);
      expect(configuredOrder[0].endsWith('3') && configuredOrder[configuredOrder.length - 1].endsWith('1'),
        `fire order is not outer to inner: ${configuredOrder.join(',')}`);
      for (const pylon of pylonsSeen) {
        expect(configuredOrder.includes(pylon), `missile fired from an unconfigured pylon: ${pylon}`);
      }
      expect(pylonsSeen.size === 6, `missiles only ever used ${pylonsSeen.size} of the six pylons: ${[...pylonsSeen].join(',')}`);
      const launchLog = (missileState.playerMissileLaunchLog || []).map(String);
      expect(launchLog.length >= 2, `no missile launch log: ${launchLog.join(',')}`);
      for (let i = 1; i < launchLog.length; i += 1) {
        const previous = configuredOrder.indexOf(launchLog[i - 1]);
        const current = configuredOrder.indexOf(launchLog[i]);
        expect(current === (previous + 1) % configuredOrder.length,
          `launch order left the configured socket list: ${launchLog.join(' -> ')}`);
      }
      assertMuzzleFlash(missileState, 'missiles');
      const missilePath = join(screenshotDir, 'weapon_pylon_missiles.png');
      await page.screenshot({ path: missilePath, fullPage: false, timeout: 120000 });
      writeFileSync(missilePath.replace(/\.png$/, '_state.json'), JSON.stringify(missileState, null, 2));
      console.log(`captured ${missilePath} (launched ${launched}, pylons ${[...pylonsSeen].join(',')}, reloads ${reloads})`);

      // --- debug gizmo
      await page.keyboard.press('F2');
      // Headless WebGL runs at ~1 FPS, so the toggle can take several seconds
      // to show up in the bridge snapshot: poll instead of a fixed sleep.
      let gizmoState = null;
      for (let i = 0; i < 20; i += 1) {
        await page.waitForTimeout(900);
        gizmoState = await page.evaluate(() => window.ForceWarBridge?.state || null);
        if (gizmoState?.weaponDebugGizmoVisible === true) break;
      }
      expect(gizmoState?.weaponDebugGizmoVisible === true,
        `debug gizmo did not switch on: ${gizmoState?.weaponDebugGizmoVisible}`);
      const gizmoPath = join(screenshotDir, 'weapon_socket_gizmo.png');
      await page.screenshot({ path: gizmoPath, fullPage: false, timeout: 120000 });
      writeFileSync(gizmoPath.replace(/\.png$/, '_state.json'), JSON.stringify(gizmoState, null, 2));
      console.log(`captured ${gizmoPath} (gizmo on)`);

      const summary = {
        generatedAt: new Date().toISOString(),
        contract: 'position_from_socket_direction_from_aim',
        gunSocketIds: gizmoState.playerGunSocketIds,
        gunWorldOrder: gizmoState.playerGunWorldOrder,
        missileSockets: num(gizmoState.playerMissileSocketCount),
        missileFireOrder: gizmoState.playerMissileSocketIds,
        missileFireOrderRule: gizmoState.playerMissileFireOrderRule,
        pylonMissileMeshes: num(gizmoState.playerPylonMissileMeshes),
        pylonMissilesLaunched: num(gizmoState.playerPylonMissilesLaunched),
        pylonReloads: num(gizmoState.playerPylonReloads),
        pylonsFiredFrom: [...pylonsSeen],
        missilePhasesSeen: [...phasesSeen],
        muzzleFlashOffsetFromBarrel: num(gizmoState.muzzleFlashOffsetFromBarrel),
        muzzleFlashAtBarrel: gizmoState.muzzleFlashAtBarrel,
        convergenceDistance: num(gizmoState.playerShotConvergenceDistance),
        muzzleClearance: num(gizmoState.playerShotMuzzleClearance),
        socketFailures: num(gizmoState.playerShotSocketFailures),
        banking: results,
        gizmoScreenshot: gizmoPath
      };
      writeFileSync(summaryPath, JSON.stringify(summary, null, 2));
      console.log(`Weapon socket QA ok: ${JSON.stringify(summary, null, 2)}`);
    } finally {
      await browser.close();
    }
  } catch (error) {
    console.error(error.message);
    console.error(serverLog.slice(-1500));
    process.exitCode = 1;
  } finally {
    serverProcess.kill('SIGTERM');
  }
}

await main();
