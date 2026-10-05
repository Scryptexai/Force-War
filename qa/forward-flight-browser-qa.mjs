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
      if (result.state?.active !== true) fail(`forward scene was not active: ${JSON.stringify(result.state)}`);
      if (result.state?.arenaPhase !== 'storm_battlefield') fail(`expected storm_battlefield arena phase, got ${result.state?.arenaPhase}`);
      if (Number(result.state?.depthLayerCount || 0) < 4) fail(`expected at least 4 depth layers, got ${result.state?.depthLayerCount}`);
      if (result.state?.weatherGameplay !== true) fail(`weather gameplay flag missing: ${JSON.stringify(result.state)}`);
      if (typeof result.state?.windDrift !== 'number') fail('windDrift was not numeric');
      if (typeof result.state?.rainVisibility !== 'number') fail('rainVisibility was not numeric');
      if (typeof result.state?.cloudCover !== 'number') fail('cloudCover was not numeric');
      if (typeof result.state?.stormHazard !== 'number') fail('stormHazard was not numeric');
      if (result.state?.bossAnchor !== true) fail(`boss anchor missing: ${JSON.stringify(result.state)}`);
      if (result.state?.visualLockComposition !== 'dreadnought_forward_battle') fail(`visual lock composition missing: ${result.state?.visualLockComposition}`);
      if (result.state?.enemyHeroJetModel !== true) fail(`uploaded enemy hero jet GLB was not active: ${JSON.stringify(result.state)}`);
      if (result.state?.shotAnimation !== 'player_cyan_pulses_enemy_red_lanes') fail(`shot animation bridge missing: ${result.state?.shotAnimation}`);
      if (result.state?.enemyHeroJetSource !== 'blender_ready_glb') fail(`Blender-generated enemy GLB not active: ${result.state?.enemyHeroJetSource}`);
      if (result.state?.enemyHeroJetAnimation !== 'EnemyJet_AttackPass_Loop') fail(`Blender animation clip not active: ${result.state?.enemyHeroJetAnimation}`);
      if (result.state?.cloudGeometry !== false) fail(`cloud geometry should be disabled, got ${result.state?.cloudGeometry}`);
      if (result.state?.playerScaleMode !== 'reduced_mobile_readable') fail(`player scale mode missing: ${result.state?.playerScaleMode}`);
      console.log(`Forward/weather browser QA ok: mode=${result.state.missionMode} camera=${result.state.cameraMode} model=${result.state.playerModel} arena=${result.state.arenaPhase} composition=${result.state.visualLockComposition} enemyHeroJet=${result.state.enemyHeroJetModel} source=${result.state.enemyHeroJetSource} anim=${result.state.enemyHeroJetAnimation} shots=${result.state.shotAnimation} clouds=${result.state.cloudGeometry} layers=${result.state.depthLayerCount} wind=${Number(result.state.windDrift).toFixed(2)} visibility=${Number(result.state.rainVisibility).toFixed(2)} progress=${Number(result.state.progress).toFixed(3)} canvas=${result.canvas.width}x${result.canvas.height}`);
    } finally {
      await browser.close();
    }
  } finally {
    serverProcess.kill('SIGTERM');
    if (serverLog.trim()) console.log(serverLog.trim());
  }
}

main().catch((error) => fail(error.stack || error.message));
