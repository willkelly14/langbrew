const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

const ROOT = __dirname;
const PORT = 3456;

const MIME = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.md': 'text/plain',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.gif': 'image/gif',
};

function getFiles(dir, base = '') {
  const results = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name.startsWith('.') || entry.name === 'node_modules' || entry.name === 'server.js' || entry.name === 'dashboard.html') continue;
    const rel = path.join(base, entry.name);
    if (entry.isDirectory()) {
      // skip design inspiration (too many images)
      if (entry.name === 'design inspiration') continue;
      results.push(...getFiles(path.join(dir, entry.name), rel));
    } else {
      const ext = path.extname(entry.name).toLowerCase();
      if (['.html', '.md', '.json', '.txt'].includes(ext)) {
        const stat = fs.statSync(path.join(dir, entry.name));
        results.push({ path: rel, size: stat.size, ext });
      }
    }
  }
  return results;
}

function readBody(req) {
  return new Promise((resolve) => {
    let body = '';
    req.on('data', (c) => body += c);
    req.on('end', () => resolve(body));
  });
}

const server = http.createServer(async (req, res) => {
  const parsed = url.parse(req.url, true);
  const pathname = parsed.pathname;

  // API: list files
  if (pathname === '/api/files') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(getFiles(ROOT)));
    return;
  }

  // API: read file
  if (pathname === '/api/file' && req.method === 'GET') {
    const filePath = parsed.query.path;
    if (!filePath) { res.writeHead(400); res.end('Missing path'); return; }
    const full = path.join(ROOT, filePath);
    if (!full.startsWith(ROOT)) { res.writeHead(403); res.end('Forbidden'); return; }
    try {
      const content = fs.readFileSync(full, 'utf-8');
      res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end(content);
    } catch (e) {
      res.writeHead(404); res.end('Not found');
    }
    return;
  }

  // API: save file
  if (pathname === '/api/file' && req.method === 'POST') {
    const body = JSON.parse(await readBody(req));
    const full = path.join(ROOT, body.path);
    if (!full.startsWith(ROOT)) { res.writeHead(403); res.end('Forbidden'); return; }
    try {
      fs.writeFileSync(full, body.content, 'utf-8');
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true }));
    } catch (e) {
      res.writeHead(500); res.end(e.message);
    }
    return;
  }

  // Serve dashboard
  if (pathname === '/' || pathname === '/dashboard.html') {
    const content = fs.readFileSync(path.join(ROOT, 'dashboard.html'), 'utf-8');
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(content);
    return;
  }

  // Static files
  const filePath = path.join(ROOT, decodeURIComponent(pathname.slice(1)));
  if (!filePath.startsWith(ROOT)) { res.writeHead(403); res.end(); return; }
  try {
    const content = fs.readFileSync(filePath);
    const ext = path.extname(filePath).toLowerCase();
    res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
    res.end(content);
  } catch {
    res.writeHead(404); res.end('Not found');
  }
});

server.listen(PORT, () => {
  console.log(`Dashboard running at http://localhost:${PORT}`);
});
