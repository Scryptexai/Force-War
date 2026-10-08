#!/usr/bin/env node
// Visual probe: boots the Web build, drives it into forward-air combat, captures a
// screenshot and dumps the live bridge state. No assertions - this is the manual
// visual gate helper used while iterating on a pass.
import { existsSync, mkdirSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import chromiumPack, { inflate, setupLambdaEnvironment } from '@sparticuz/chromium';
import { chromium as playwrightChromium } from 'playwright-core';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sparticuzBin = join(root, 'node_modules', '@sparticuz', 'chromium', 'bin');
const port = Number(process.env.QA_PROBE_PORT || 9600 + Math.floor(Math.random() * 300));
const screenshotDir = join(root, 'qa', 'screenshots');
const label = process.env.QA_PROBE_LABEL || 'pass1_probe';
const waitMs = Number(process.env.QA_PROBE_WAIT || 9000);
const shots = Number(process.env.QA_PROBE_SHOTS || 1);
const shotGap = Number(process.env.QA_PROBE_GAP || 1700);

async function waitForHealth(serverProcess) {
  const started = Date.now();
  while (Date.now() - started < 30000) {
    if (serverProcess.exitCode !== null) throw new Error(`server exited ${serverProcess.exitCode}`);
    try {
      const response = await fetch(`http://127.0.0.1:${port}/healthz`);
      if (response.ok) return;
    } catch { /* retry */ }
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error('server never became healthy');
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

async function main() {
  const serverProcess = spawn(process.execPath, ['server.js'], {
    cwd: root,
    env: { ...process.env, PORT: String(port), HOST: '0.0.0.0' },
    stdio: ['ignore', 'pipe', 'pipe']
  });
  let serverLog = '';
  serverProcess.stdout.on('data', (c) => { serverLog += c.toString(); });
  serverProcess.stderr.on('data', (c) => { serverLog += c.toString(); });

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
      page.on('pageerror', (e) => pageErrors.push(e.message));
      page.on('console', (m) => { if (m.type() === 'error') pageErrors.push(`console: ${m.text()}`); });
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
      await page.waitForTimeout(waitMs);

      mkdirSync(screenshotDir, { recursive: true });
      // Headless-Chromium frame-rate PROXY. This is a software/VM WebGL number,
      // NOT a phone measurement; it is only used to compare before/after a Pass 3
      // addition on identical hardware.
      const fpsSample = await page.evaluate(() => new Promise((done) => {
        const times = [];
        let last = performance.now();
        const started = last;
        function tick(now) {
          times.push(now - last);
          last = now;
          if (now - started < 3000) requestAnimationFrame(tick);
          else {
            const sorted = times.slice().sort((a, b) => a - b);
            const mean = times.reduce((a, b) => a + b, 0) / Math.max(1, times.length);
            done({
              frames: times.length,
              avgFps: Math.round((1000 / mean) * 10) / 10,
              p95FrameMs: Math.round(sorted[Math.floor(sorted.length * 0.95)] * 10) / 10
            });
          }
        }
        requestAnimationFrame(tick);
      }));
      console.log(`fpsProxyHeadlessChromium: ${JSON.stringify(fpsSample)}`);
      // Drag the aircraft around so freeze frames are not all the same pose.
      const track = [[250, 980], [470, 860], [300, 1050], [520, 960], [360, 900]];
      let state = null;
      for (let shotIndex = 0; shotIndex < shots; shotIndex += 1) {
        const point = track[shotIndex % track.length];
        await page.mouse.move(point[0], point[1]);
        await page.mouse.down();
        await page.waitForTimeout(shotGap);
        state = await page.evaluate(() => window.ForceWarBridge?.state || null);
        const suffix = shots > 1 ? `_${shotIndex + 1}` : '';
        const framePath = join(screenshotDir, `${label}${suffix}.png`);
        await page.screenshot({ path: framePath, fullPage: false });
        writeFileSync(join(screenshotDir, `${label}${suffix}_state.json`), JSON.stringify(state, null, 2));
        console.log(`screenshot ${framePath} (${statSync(framePath).size} bytes)`);
        await page.mouse.up();
      }
      console.log(`pageErrors: ${pageErrors.length ? pageErrors.join(' | ') : 'none'}`);
      const keys = (process.env.QA_PROBE_KEYS || 'screen,missionMode,bossPhase,bossPhaseName,bossHpRatio,bossShieldRatio,bossTurretLeftRatio,bossTurretRightRatio,bossCoreRatio,bossTargetablePart,bossAttackState,bossTelegraphPart,bossFireEventCount,bossLiveMuzzleCount,activeLogicalProjectiles,activePlayerProjectiles,playerProjectileHits,projectileShotsSpawned,projectileHitsTaken,hp,shield,score,playerWorldZ,bossWorldZ,bossModelLoaded,bossDestroyedParts').split(',');
      for (const k of keys) console.log(`  ${k} = ${JSON.stringify(state?.[k])}`);
    } finally {
      await browser.close();
    }
  } catch (error) {
    console.error(error.message);
    console.error(serverLog);
    process.exitCode = 1;
  } finally {
    serverProcess.kill('SIGTERM');
  }
}

await main();
