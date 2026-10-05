#!/usr/bin/env node
import { createReadStream, existsSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { createGzip } from 'node:zlib';
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
  ['.jpg', 'image/jpeg'],
  ['.jpeg', 'image/jpeg'],
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
  res.setHeader('Vary', 'Accept-Encoding');
  const shellPaths = new Set(['/', '/index.html']);
  const enginePaths = new Set(['/index.js', '/index.wasm', '/index.pck', '/index.png', '/index.icon.png', '/index.apple-touch-icon.png']);
  if (shellPaths.has(pathname)) {
    res.setHeader('Cache-Control', 'no-cache');
  } else if (enginePaths.has(pathname)) {
    // The Web export can be large. Let browsers keep it, but revalidate with ETag
    // so refreshes do not redownload the whole Godot WASM/PCK payload.
    res.setHeader('Cache-Control', 'public, max-age=0, must-revalidate');
  } else {
    res.setHeader('Cache-Control', 'public, max-age=3600');
  }
}

function makeEtag(stat) {
  return `W/"${stat.size.toString(16)}-${Math.floor(stat.mtimeMs).toString(16)}"`;
}

function requestAcceptsGzip(req, filePath) {
  const ext = extname(filePath).toLowerCase();
  if (!['.wasm', '.pck', '.js'].includes(ext)) return false;
  return String(req.headers['accept-encoding'] || '').includes('gzip');
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
  const etag = makeEtag(stat);
  setGodotHeaders(res, requestUrl.pathname);
  res.setHeader('ETag', etag);
  res.setHeader('Last-Modified', stat.mtime.toUTCString());

  const ifNoneMatch = req.headers['if-none-match'];
  const ifModifiedSince = req.headers['if-modified-since'];
  const notModifiedByEtag = ifNoneMatch && String(ifNoneMatch).split(',').map((v) => v.trim()).includes(etag);
  const notModifiedByDate = ifModifiedSince && Date.parse(String(ifModifiedSince)) >= Math.floor(stat.mtimeMs / 1000) * 1000;
  if (notModifiedByEtag || notModifiedByDate) {
    res.writeHead(304);
    res.end();
    return;
  }

  const gzip = method === 'GET' && requestAcceptsGzip(req, filePath);
  const headers = {
    'Content-Type': contentType(filePath)
  };
  if (gzip) {
    headers['Content-Encoding'] = 'gzip';
  } else {
    headers['Content-Length'] = stat.size;
  }
  res.writeHead(200, headers);

  if (method === 'HEAD') {
    res.end();
    return;
  }

  const stream = createReadStream(filePath);
  if (gzip) {
    stream.pipe(createGzip({ level: 6 })).pipe(res);
  } else {
    stream.pipe(res);
  }
});

server.listen(port, host, () => {
  console.log(`Force War Web server running from ${projectRoot}`);
  console.log(`Serving static root ${staticRoot}`);
  console.log(`Listening on http://${host}:${port}`);
});

process.on('SIGTERM', () => server.close(() => process.exit(0)));
process.on('SIGINT', () => server.close(() => process.exit(0)));
