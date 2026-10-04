#!/usr/bin/env node
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import chromiumPack, { inflate, setupLambdaEnvironment } from '@sparticuz/chromium';
import { chromium as playwrightChromium } from 'playwright-core';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const godotVersion = '4.6.2.stable';
const godotZip = join(root, 'Godot_v4.6.2-stable_linux.x86_64.zip');
const templateDebug = join(root, 'web_nothreads_debug.zip');
const templateRelease = join(root, 'web_nothreads_release.zip');
const tmpGodotBin = '/tmp/force-war-godot-4.6.2/Godot_v4.6.2-stable_linux.x86_64';
const sparticuzBin = join(root, 'node_modules', '@sparticuz', 'chromium', 'bin');

function fail(message) {
  console.error(`QA failed: ${message}`);
  process.exit(1);
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: root,
    encoding: 'utf8',
    maxBuffer: 1024 * 1024 * 64,
    ...options
  });
  if (result.status !== 0) {
    if (result.stdout) console.error(result.stdout);
    if (result.stderr) console.error(result.stderr);
    fail(`${command} ${args.join(' ')} exited with ${result.status}`);
  }
  return result.stdout || '';
}

function isValidGodot(binary) {
  if (!binary || !existsSync(binary)) return false;
  const result = spawnSync(binary, ['--version'], { encoding: 'utf8', maxBuffer: 1024 * 1024 });
  return result.status === 0 && /^4\.6\.2\.stable/.test(result.stdout || '');
}

function findGodot() {
  const candidates = [
    process.env.GODOT_BIN,
    tmpGodotBin,
    join(root, 'godot_v4.6.2-stable-linux_release.x86_64'),
    'godot'
  ].filter(Boolean);

  for (const candidate of candidates) {
    if (candidate === 'godot') {
      const version = spawnSync(candidate, ['--version'], { encoding: 'utf8', maxBuffer: 1024 * 1024 });
      if (version.status === 0 && /^4\.6\.2\.stable/.test(version.stdout || '')) return candidate;
    } else if (isValidGodot(candidate)) {
      return candidate;
    }
  }

  if (!existsSync(godotZip)) fail(`Godot 4.6.2 zip not found: ${godotZip}`);
  mkdirSync(dirname(tmpGodotBin), { recursive: true });
  run('unzip', ['-o', godotZip, '-d', dirname(tmpGodotBin)]);
  run('chmod', ['+x', tmpGodotBin]);
  if (!isValidGodot(tmpGodotBin)) fail(`Invalid Godot binary after unzip: ${tmpGodotBin}`);
  return tmpGodotBin;
}

function prepareTemplates() {
  if (!existsSync(templateDebug)) fail('web_nothreads_debug.zip missing in repository root');
  if (!existsSync(templateRelease)) fail('web_nothreads_release.zip missing in repository root');
  const templateDir = join(process.env.XDG_DATA_HOME || join(homedir(), '.local', 'share'), 'godot', 'export_templates', godotVersion);
  mkdirSync(templateDir, { recursive: true });
  copyFileSync(templateDebug, join(templateDir, 'web_nothreads_debug.zip'));
  copyFileSync(templateRelease, join(templateDir, 'web_nothreads_release.zip'));
  const preset = readFileSync(join(root, 'export_presets.cfg'), 'utf8');
  if (!preset.includes('custom_template/debug="res://web_nothreads_debug.zip"')) {
    fail('export_presets.cfg is not pointing debug export to res://web_nothreads_debug.zip');
  }
}

async function waitForHealth(port, serverProcess) {
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

async function assertHead(url, expectedType) {
  const response = await fetch(url, { method: 'HEAD' });
  if (!response.ok) fail(`${url} returned ${response.status}`);
  const type = response.headers.get('content-type') || '';
  if (!type.includes(expectedType)) fail(`${url} content-type '${type}' does not include '${expectedType}'`);
  const coop = response.headers.get('cross-origin-opener-policy') || '';
  const coep = response.headers.get('cross-origin-embedder-policy') || '';
  if (coop !== 'same-origin') fail(`${url} missing COOP same-origin`);
  if (coep !== 'require-corp') fail(`${url} missing COEP require-corp`);
}

async function launchBrowser() {
  // Locally, @sparticuz/chromium may still need its bundled AL2023 libraries.
  // Vercel/Lambda sets this automatically; for QA in this sandbox we prepare it explicitly.
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
  prepareTemplates();
  const nodeModules = join(root, 'node_modules');
  if (existsSync(nodeModules)) writeFileSync(join(nodeModules, '.gdignore'), 'Ignored by Godot export scans.\n');
  const godot = findGodot();
  const debugOut = mkdtempSync(join(tmpdir(), 'force-war-web-debug-'));
  console.log(`Exporting debug Web build with ${godot}`);
  run(godot, ['--headless', '--path', root, '--export-debug', 'Web', join(debugOut, 'index.html')], { stdio: 'inherit' });

  for (const file of ['index.html', 'index.js', 'index.wasm', 'index.pck']) {
    const path = join(debugOut, file);
    if (!existsSync(path) || statSync(path).size <= 0) fail(`debug export missing ${file}`);
  }

  const port = Number(process.env.QA_PORT || 8300 + Math.floor(Math.random() * 500));
  const serverProcess = spawn(process.execPath, ['server.js'], {
    cwd: root,
    env: { ...process.env, PORT: String(port), HOST: '0.0.0.0', STATIC_ROOT: debugOut },
    stdio: ['ignore', 'pipe', 'pipe']
  });
  let serverLog = '';
  serverProcess.stdout.on('data', (chunk) => { serverLog += chunk.toString(); });
  serverProcess.stderr.on('data', (chunk) => { serverLog += chunk.toString(); });

  try {
    await waitForHealth(port, serverProcess);
    await assertHead(`http://127.0.0.1:${port}/index.html`, 'text/html');
    await assertHead(`http://127.0.0.1:${port}/index.js`, 'text/javascript');
    await assertHead(`http://127.0.0.1:${port}/index.wasm`, 'application/wasm');
    await assertHead(`http://127.0.0.1:${port}/index.pck`, 'application/octet-stream');

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
      await page.waitForFunction(() => {
        const canvas = document.querySelector('canvas');
        return !!canvas && canvas.width > 0 && canvas.height > 0;
      }, null, { timeout: 60000 });
      await page.waitForTimeout(7000);
      const state = await page.evaluate(() => {
        const canvas = document.querySelector('canvas');
        return {
          hasBridge: !!window.ForceWarBridge,
          bridgeVersion: window.ForceWarBridge?.version || null,
          bridgeState: window.ForceWarBridge?.state || null,
          canvas: canvas ? { width: canvas.width, height: canvas.height } : null,
          bodyText: document.body.innerText.slice(0, 300)
        };
      });
      if (!state.hasBridge) fail('window.ForceWarBridge was not available after loading Godot Web page');
      if (!state.canvas || state.canvas.width !== 720 || state.canvas.height !== 1280) {
        fail(`expected 9:16 canvas 720x1280, got ${state.canvas?.width}x${state.canvas?.height}`);
      }
      if (pageErrors.length > 0) fail(`browser page errors: ${pageErrors.join(' | ')}`);
      console.log(`QA browser ok: canvas=${state.canvas?.width}x${state.canvas?.height} bridge=${state.bridgeVersion}`);
    } finally {
      await browser.close();
    }
  } finally {
    serverProcess.kill('SIGTERM');
    rmSync(debugOut, { recursive: true, force: true });
    if (serverLog.trim()) console.log(serverLog.trim());
  }
}

main().catch((error) => fail(error.stack || error.message));
