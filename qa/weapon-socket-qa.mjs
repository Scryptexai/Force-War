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
//   * the debug gizmo can be switched on and reports itself.
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

  // It must be a barrel, not the hull centre.
  expect(Math.abs(socketX - num(state.lastPlayerShotAimX)) > 0.25,
    `[${label}] shot origin collapsed onto the aircraft centre line: socketX=${socketX}`);
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
            const socket = String(state.lastPlayerShotSocket || '');
            if (socket && socket !== 'none') {
              perGunDirections.set(socket, {
                socketX: num(state.lastPlayerShotSocketX),
                dirX: num(state.lastPlayerShotDirX),
                aimX: num(state.lastPlayerShotAimX)
              });
            }
          }
          if (state && Math.abs(num(state.playerRollDegrees)) > 6) break;
        }
        const path = join(screenshotDir, bank.file);
        await page.screenshot({ path, fullPage: false });
        writeFileSync(path.replace(/\.png$/, '_state.json'), JSON.stringify(state, null, 2));
        assertSocketContract(state, bank.label);
        assertShotGeometry(state, bank.label);
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

      // --- debug gizmo
      await page.keyboard.press('F2');
      await page.waitForTimeout(900);
      const gizmoState = await page.evaluate(() => window.ForceWarBridge?.state || null);
      expect(gizmoState?.weaponDebugGizmoVisible === true,
        `debug gizmo did not switch on: ${gizmoState?.weaponDebugGizmoVisible}`);
      const gizmoPath = join(screenshotDir, 'weapon_socket_gizmo.png');
      await page.screenshot({ path: gizmoPath, fullPage: false });
      writeFileSync(gizmoPath.replace(/\.png$/, '_state.json'), JSON.stringify(gizmoState, null, 2));
      console.log(`captured ${gizmoPath} (gizmo on)`);

      const summary = {
        generatedAt: new Date().toISOString(),
        contract: 'position_from_socket_direction_from_aim',
        gunSocketIds: gizmoState.playerGunSocketIds,
        gunWorldOrder: gizmoState.playerGunWorldOrder,
        missileSockets: num(gizmoState.playerMissileSocketCount),
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
