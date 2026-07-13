import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = normalize(join(fileURLToPath(new URL('.', import.meta.url)), '..', 'build', 'web'));
const mime = new Map([
  ['.html', 'text/html; charset=utf-8'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.wasm', 'application/wasm'],
  ['.png', 'image/png'],
  ['.svg', 'image/svg+xml'],
  ['.otf', 'font/otf'],
  ['.bin', 'application/octet-stream'],
  ['.frag', 'application/octet-stream'],
]);

createServer(async (request, response) => {
  const url = new URL(request.url ?? '/', 'http://127.0.0.1');
  if (url.pathname === '/Veredra') {
    response.writeHead(301, { location: '/Veredra/' });
    response.end();
    return;
  }
  if (!url.pathname.startsWith('/Veredra/')) {
    response.writeHead(404);
    response.end('Not found');
    return;
  }
  let relative = decodeURIComponent(url.pathname.slice('/Veredra/'.length));
  if (!relative || relative.endsWith('/')) relative += 'index.html';
  let target = normalize(join(root, relative));
  if (!target.startsWith(root)) {
    response.writeHead(400);
    response.end('Invalid path');
    return;
  }
  try {
    if (!(await stat(target)).isFile()) throw new Error('not a file');
  } catch {
    target = join(root, 'index.html');
  }
  const content = await readFile(target);
  const headers = {
    'content-type': mime.get(extname(target)) ?? 'application/octet-stream',
    'cross-origin-opener-policy': 'same-origin',
    'cross-origin-resource-policy': 'same-origin',
    'x-content-type-options': 'nosniff',
  };
  headers['cache-control'] = target.endsWith('flutter_service_worker.js')
    ? 'no-cache, no-store, must-revalidate'
    : 'public, max-age=60';
  response.writeHead(200, headers);
  response.end(content);
}).listen(4173, '127.0.0.1');
