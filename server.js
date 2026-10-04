#!/usr/bin/env node
import { createReadStream, existsSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join, normalize, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = resolve(fileURLToPath(new URL('.', import.meta.url)));
const host = process.env.HOST || '0.0.0.0';
const port = Number(process.env.PORT || 8000);
const staticRoot = resolve(process.env.STATIC_ROOT || process.argv[2] || projectRoot);

const mimeTypes = new Map([
  ['.html', 'text/html; charset=utf-8'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.mjs', 'text/javascript; charset=utf-8'],
  ['.wasm', 'application/wasm'],
  ['.pck', 'application/octet-stream'],
  ['.png', 'image/png'],
  ['.svg', 'image/svg+xml'],
  ['.json', 'application/json; charset=utf-8'],
  ['.ico', 'image/x-icon'],
  ['.txt', 'text/plain; charset=utf-8']
]);

function contentType(pathname) {
  if (pathname.endsWith('.worker.js') || pathname.endsWith('.worklet.js')) {
    return 'text/javascript; charset=utf-8';
  }
  return mimeTypes.get(extname(pathname).toLowerCase()) || 'application/octet-stream';
}

function safeResolve(urlPathname) {
  let decoded;
  try {
    decoded = decodeURIComponent(urlPathname.split('?')[0]);
  } catch {
    return null;
  }

  if (decoded === '/' || decoded === '') decoded = '/index.html';
  const normal = normalize(decoded).replace(/^([/\\])+/, '');
  const absolute = resolve(join(staticRoot, normal));
  const rootWithSep = staticRoot.endsWith(sep) ? staticRoot : `${staticRoot}${sep}`;
  if (absolute !== staticRoot && !absolute.startsWith(rootWithSep)) return null;
  return absolute;
}

function setGodotHeaders(res, pathname) {
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Permissions-Policy', 'interest-cohort=()');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Cache-Control', pathname === '/index.html' || pathname === '/' ? 'no-cache' : 'public, max-age=3600');
}

if (!existsSync(join(staticRoot, 'index.html'))) {
  console.error(`index.html not found in ${staticRoot}`);
  console.error('Run the Godot Web export first or set STATIC_ROOT to a directory that contains index.html.');
  process.exit(1);
}

const server = createServer((req, res) => {
  const method = req.method || 'GET';
  const requestUrl = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);

  if (requestUrl.pathname === '/healthz') {
    setGodotHeaders(res, requestUrl.pathname);
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ ok: true, staticRoot, projectRoot }));
    return;
  }

  if (method !== 'GET' && method !== 'HEAD') {
    setGodotHeaders(res, requestUrl.pathname);
    res.writeHead(405, { Allow: 'GET, HEAD' });
    res.end('Method Not Allowed');
    return;
  }

  const filePath = safeResolve(requestUrl.pathname);
  if (!filePath) {
    setGodotHeaders(res, requestUrl.pathname);
    res.writeHead(400, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Bad Request');
    return;
  }

  if (!existsSync(filePath) || !statSync(filePath).isFile()) {
    setGodotHeaders(res, requestUrl.pathname);
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not Found');
    return;
  }

  const stat = statSync(filePath);
  setGodotHeaders(res, requestUrl.pathname);
  res.writeHead(200, {
    'Content-Type': contentType(filePath),
    'Content-Length': stat.size,
    'Last-Modified': stat.mtime.toUTCString()
  });

  if (method === 'HEAD') {
    res.end();
    return;
  }

  createReadStream(filePath).pipe(res);
});

server.listen(port, host, () => {
  console.log(`Force War Web server running from ${projectRoot}`);
  console.log(`Serving static root ${staticRoot}`);
  console.log(`Listening on http://${host}:${port}`);
});

process.on('SIGTERM', () => server.close(() => process.exit(0)));
process.on('SIGINT', () => server.close(() => process.exit(0)));
