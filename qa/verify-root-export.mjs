#!/usr/bin/env node
import { existsSync, statSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(new URL('..', import.meta.url).pathname);
const required = [
  ['index.html', 1024],
  ['index.js', 1024],
  ['index.wasm', 1024 * 1024],
  ['index.pck', 1024 * 512]
];

let ok = true;
for (const [file, minSize] of required) {
  const path = resolve(root, file);
  if (!existsSync(path)) {
    console.error(`Missing required Web export file: ${file}`);
    ok = false;
    continue;
  }
  const size = statSync(path).size;
  if (size < minSize) {
    console.error(`Web export file is unexpectedly small: ${file} (${size} bytes)`);
    ok = false;
  } else {
    console.log(`${file} ${size}`);
  }
}

if (!existsSync(resolve(root, 'server.js'))) {
  console.error('Missing root server.js. Vercel/root npm start must serve from repository root.');
  ok = false;
}

if (!existsSync(resolve(root, 'web_nothreads_debug.zip'))) {
  console.warn('web_nothreads_debug.zip not present; Vercel build can continue, but local npm run qa:web requires it.');
}

process.exit(ok ? 0 : 1);
