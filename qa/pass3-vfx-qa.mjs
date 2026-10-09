#!/usr/bin/env node
// Pass 3 QA - air enemies and explosion VFX.
//
// Correction brief, Pass 3 items 1 and 2: one or two air enemy types with
// distinct silhouettes and red eyes that fire from visible muzzles, and
// explosions built from flash + fireball + smoke + debris with NO per
// explosion dynamic light.
//
// This script drives the real Web export, polls the live bridge at high
// frequency, and captures the frames that actually matter:
//   * a frame while hostile aircraft are inside the midfield,
//   * the frame right after a kill, while its explosion is still playing.
// It then asserts the Pass 3 contract on the captured state.
import { existsSync, mkdirSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import chromiumPack, { inflate, setupLambdaEnvironment } from '@sparticuz/chromium';
import { chromium as playwrightChromium } from 'playwright-core';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sparticuzBin = join(root, 'node_modules', '@sparticuz', 'chromium', 'bin');
const port = Number(process.env.QA_PASS3_PORT || 9500 + Math.floor(Math.random() * 400));
const screenshotDir = join(root, 'qa', 'screenshots');
const summaryPath = join(screenshotDir, 'pass3_vfx_qa_summary.json');
const HUNT_MS = Number(process.env.QA_PASS3_HUNT || 150000);

function fail(message) {
  console.error(`Pass 3 VFX QA failed: ${message}`);
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
  await page.waitForTimeout(6000);
}

function assertEnemyContract(state, label) {
  expect(state?.airEnemyEntities === true, `[${label}] air enemies are not real entities: ${state?.airEnemyEntities}`);
  expect(state?.airEnemyModelLoaded === true, `[${label}] air enemy 3D model not loaded: ${state?.airEnemyModelLoaded}`);
  expect(Array.isArray(state?.airEnemyTypes) && state.airEnemyTypes.length >= 2,
    `[${label}] fewer than two air enemy types: ${JSON.stringify(state?.airEnemyTypes)}`);
  expect(state?.airEnemyThreatMarker === 'red_eye_emissive', `[${label}] red eye threat marker missing: ${state?.airEnemyThreatMarker}`);
  expect(state?.airEnemyHitboxModel === 'per_unit_world_box_on_combat_plane',
    `[${label}] air enemy hitbox model: ${state?.airEnemyHitboxModel}`);
  expect(state?.airEnemyHomingBullets === false, `[${label}] air enemy bullets are homing: ${state?.airEnemyHomingBullets}`);
  expect(state?.enemyBulletSourceModel === 'boss_and_air_enemy_muzzle_fire_events_only',
    `[${label}] enemy bullet source model regressed: ${state?.enemyBulletSourceModel}`);
  // No per-explosion dynamic light is allowed; the VFX is emissive only.
  expect(num(state?.explosionDynamicLights) === 0, `[${label}] explosions created dynamic lights: ${state?.explosionDynamicLights}`);
  expect(num(state?.explosionPoolSize) > 0, `[${label}] explosion pool missing: ${state?.explosionPoolSize}`);
  expect(state?.missileVisualModel === 'fire_head_plus_white_smoke_trail',
    `[${label}] missile visual model: ${state?.missileVisualModel}`);
  expect(state?.missileTracking === false, `[${label}] missiles are homing: ${state?.missileTracking}`);
  expect(num(state?.missileVisualPoolSize) > 0, `[${label}] missile visual pool missing: ${state?.missileVisualPoolSize}`);
  // Pass 3, item 4: the under-world is populated and non-interactive.
  expect(state?.underworldSpeedLayer === true, `[${label}] under-world speed layer missing: ${state?.underworldSpeedLayer}`);
  expect(state?.underworldInteractive === false, `[${label}] under-world became interactive: ${state?.underworldInteractive}`);
  expect(num(state?.underworldCliffCount) > 0, `[${label}] no cliffs: ${state?.underworldCliffCount}`);
  expect(num(state?.underworldWreckCount) > 0, `[${label}] no wrecks: ${state?.underworldWreckCount}`);
  expect(num(state?.underworldCityBlockCount) > 0, `[${label}] no burning city: ${state?.underworldCityBlockCount}`);
  expect(num(state?.underworldSmokeColumnCount) > 0, `[${label}] no smoke columns: ${state?.underworldSmokeColumnCount}`);
  expect(num(state?.underworldSpeedStreakCount) > 0, `[${label}] no speed streaks: ${state?.underworldSpeedStreakCount}`);
  // Pass 1 contract must still hold with the Pass 3 content switched on.
  expect(state?.pass1CausalityContract === 'boss_entity_owns_state_bullets_from_visible_muzzles',
    `[${label}] pass 1 causality contract lost: ${state?.pass1CausalityContract}`);
  expect(state?.hudValuesHardcoded === false, `[${label}] HUD is reporting hard-coded values: ${state?.hudValuesHardcoded}`);
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

  const captures = [];
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
      await launchMission(page);
      mkdirSync(screenshotDir, { recursive: true });

      // Hold the trigger down and sweep so the squadron is actually engaged.
      await page.mouse.move(360, 940);
      await page.mouse.down();

      let lastKills = 0;
      let midfieldShots = 0;
      let killShots = 0;
      let kindsSeen = new Set();
      let missileShots = 0;
      let seenMissilesFired = 0;
      let seenFireEvents = 0;
      let seenHits = 0;
      const started = Date.now();
      let sweep = 0;
      while (Date.now() - started < HUNT_MS && (midfieldShots < 2 || killShots < 2 || missileShots < 1)) {
        sweep += 1;
        await page.mouse.move(360 + Math.sin(sweep * 0.35) * 170, 930 + Math.cos(sweep * 0.5) * 70);
        const state = await page.evaluate(() => window.ForceWarBridge?.state || null);
        if (!state) { await page.waitForTimeout(150); continue; }
        for (const kind of state.airEnemyLiveKinds || []) kindsSeen.add(kind);
        seenFireEvents = Math.max(seenFireEvents, num(state.airEnemyFireEvents));
        seenHits = Math.max(seenHits, num(state.airEnemyHitsLanded));
        const kills = num(state.airEnemyKilled);
        const nearestZ = num(state.airEnemyNearestZ);

        if (kills > lastKills && killShots < 2) {
          lastKills = kills;
          killShots += 1;
          // The bridge reports the kill one frame before the director spawns its
          // explosion, so sample a short burst and keep the frame that actually
          // has explosion geometry alive.
          let best = null;
          for (const delay of [0, 220, 420, 700]) {
            await page.waitForTimeout(delay === 0 ? 90 : delay);
            const shotState = await page.evaluate(() => window.ForceWarBridge?.state || null);
            const path = join(screenshotDir, `pass3_explosion_${killShots}.png`);
            if (!best || num(shotState?.explosionVisibleCount) > 0) {
              await page.screenshot({ path, fullPage: false });
              best = { path, state: shotState };
            }
            if (num(shotState?.explosionVisibleCount) > 0) break;
          }
          const shotState = best.state;
          const path = best.path;
          writeFileSync(path.replace(/\.png$/, '_state.json'), JSON.stringify(shotState, null, 2));
          captures.push({
            label: `explosion_${killShots}`,
            path,
            kills,
            explosionEvents: num(shotState?.explosionEvents),
            explosionVisibleCount: num(shotState?.explosionVisibleCount),
            explosionX: num(shotState?.lastExplosionX),
            explosionZ: num(shotState?.lastExplosionZ)
          });
          assertEnemyContract(shotState, `explosion_${killShots}`);
          console.log(`captured ${path} (kill #${kills}, explosions ${num(shotState?.explosionEvents)}, visible ${num(shotState?.explosionVisibleCount)}, at x=${num(shotState?.lastExplosionX).toFixed(1)} z=${num(shotState?.lastExplosionZ).toFixed(1)})`);
        } else if (kills > lastKills) {
          lastKills = kills;
        }

        if (num(state.activeMissiles) > 0 && missileShots < 1) {
          // Let the missile fly for a moment so its smoke trail has been laid
          // down, then keep the frame only if a missile is still airborne.
          await page.waitForTimeout(320);
          const path = join(screenshotDir, 'pass3_missile_1.png');
          await page.screenshot({ path, fullPage: false });
          const flightState = await page.evaluate(() => window.ForceWarBridge?.state || null);
          if (num(flightState?.activeMissiles) > 0) {
            missileShots += 1;
            writeFileSync(path.replace(/\.png$/, '_state.json'), JSON.stringify(flightState, null, 2));
            captures.push({ label: 'missile_1', path, activeMissiles: num(flightState.activeMissiles), missilesFired: num(flightState.missilesFired) });
            assertEnemyContract(flightState, 'missile_1');
            console.log(`captured ${path} (active missiles ${num(flightState.activeMissiles)}, fired ${num(flightState.missilesFired)})`);
          }
        }
        seenMissilesFired = Math.max(seenMissilesFired, num(state.missilesFired));

        if (num(state.airEnemyLiveCount) > 0 && nearestZ > -24 && midfieldShots < 2) {
          midfieldShots += 1;
          const path = join(screenshotDir, `pass3_air_enemy_${midfieldShots}.png`);
          await page.screenshot({ path, fullPage: false });
          writeFileSync(path.replace(/\.png$/, '_state.json'), JSON.stringify(state, null, 2));
          captures.push({ label: `air_enemy_${midfieldShots}`, path, nearestZ, live: num(state.airEnemyLiveCount) });
          assertEnemyContract(state, `air_enemy_${midfieldShots}`);
          console.log(`captured ${path} (live ${num(state.airEnemyLiveCount)}, nearest z ${nearestZ.toFixed(1)})`);
        }
        await page.waitForTimeout(90);
      }

      for (let attempt = 0; attempt < 6 && missileShots === 0; attempt += 1) {
        // Polling the bridge from the test loop can simply miss a two second
        // flight; waitForFunction samples far faster than the loop does.
        await page.waitForFunction(() => Number(window.ForceWarBridge?.state?.activeMissiles || 0) > 0,
          null, { timeout: 60000, polling: 30 });
        // Read the state that satisfied the wait, then grab the frame: at the
        // sandbox's low headless frame rate the screenshot itself takes longer
        // than one game frame, so a post-shot read can miss the flight.
        const flightState = await page.evaluate(() => window.ForceWarBridge?.state || null);
        const path = join(screenshotDir, 'pass3_missile_1.png');
        await page.screenshot({ path, fullPage: false });
        if (num(flightState?.activeMissiles) <= 0) continue;
        missileShots += 1;
        seenMissilesFired = Math.max(seenMissilesFired, num(flightState?.missilesFired));
        writeFileSync(path.replace(/\.png$/, '_state.json'), JSON.stringify(flightState, null, 2));
        captures.push({ label: 'missile_1', path, activeMissiles: num(flightState?.activeMissiles), missilesFired: num(flightState?.missilesFired) });
        assertEnemyContract(flightState, 'missile_1');
        console.log(`captured ${path} (active missiles ${num(flightState?.activeMissiles)}, fired ${num(flightState?.missilesFired)}, lead x=${num(flightState?.missileLeadX).toFixed(1)} z=${num(flightState?.missileLeadZ).toFixed(1)} trail=${num(flightState?.missileLeadTrail)})`);
      }
      await page.mouse.up();

      // The under-world must actually scroll: sample the travelled distance twice.
      const scrollBefore = num(await page.evaluate(() => window.ForceWarBridge?.state?.underworldScrollDistance));
      // Headless software rendering runs at ~1 fps here, so a short sample can
      // fall entirely between two game frames.
      await page.waitForTimeout(4000);
      const scrollAfter = num(await page.evaluate(() => window.ForceWarBridge?.state?.underworldScrollDistance));
      expect(scrollAfter > scrollBefore,
        `under-world is not scrolling: ${scrollBefore} -> ${scrollAfter}`);
      console.log(`under-world scroll ${scrollBefore.toFixed(1)} -> ${scrollAfter.toFixed(1)}`);

      const finalState = await page.evaluate(() => window.ForceWarBridge?.state || null);
      assertEnemyContract(finalState, 'final');
      expect(midfieldShots >= 2, `hostile aircraft never reached the midfield (captured ${midfieldShots})`);
      expect(killShots >= 2, `fewer than two air kills were captured (${killShots})`);
      const explosionCaptures = captures.filter((capture) => capture.label.startsWith('explosion'));
      expect(explosionCaptures.some((capture) => capture.explosionVisibleCount > 0),
        'no captured kill frame contained live explosion geometry');
      expect(kindsSeen.size >= 2, `only one air enemy silhouette was ever live: ${[...kindsSeen].join(',')}`);
      expect(seenFireEvents > 0, 'air enemies never fired from their muzzles');
      expect(seenHits > 0, 'player shots never damaged an air enemy');
      expect(seenMissilesFired > 0, 'no gunship ever launched a missile');
      expect(missileShots >= 1, 'no frame captured a missile in flight');
      expect(num(finalState.explosionEvents) >= num(finalState.airEnemyKilled),
        `kills without an explosion: ${num(finalState.airEnemyKilled)} kills vs ${num(finalState.explosionEvents)} explosions`);

      const summary = {
        generatedAt: new Date().toISOString(),
        pass: 'pass3_air_enemies_and_explosions',
        kindsSeen: [...kindsSeen],
        airEnemySpawned: num(finalState.airEnemySpawned),
        airEnemyKilled: num(finalState.airEnemyKilled),
        airEnemyFireEvents: seenFireEvents,
        airEnemyHitsLanded: seenHits,
        missilesFired: num(finalState.missilesFired),
        missileImpacts: num(finalState.missileImpacts),
        explosionEvents: num(finalState.explosionEvents),
        explosionDynamicLights: num(finalState.explosionDynamicLights),
        underworldScrollDistance: num(finalState.underworldScrollDistance),
        underworldCliffCount: num(finalState.underworldCliffCount),
        underworldWreckCount: num(finalState.underworldWreckCount),
        underworldCityBlockCount: num(finalState.underworldCityBlockCount),
        underworldSmokeColumnCount: num(finalState.underworldSmokeColumnCount),
        underworldSpeedStreakCount: num(finalState.underworldSpeedStreakCount),
        captures: captures.map((capture) => ({ ...capture, bytes: statSync(capture.path).size }))
      };
      writeFileSync(summaryPath, JSON.stringify(summary, null, 2));
      console.log(`Pass 3 VFX QA ok: ${JSON.stringify(summary, null, 2)}`);
    } finally {
      await browser.close();
    }
  } catch (error) {
    console.error(error.message);
    console.error(serverLog.slice(-2000));
    process.exitCode = 1;
  } finally {
    serverProcess.kill('SIGTERM');
  }
}

await main();
