// Renders index.html frame by frame into frames/. Usage: node render.mjs [fps] [t1,t2,... for previews]
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright-core';

const root = path.dirname(new URL(import.meta.url).pathname);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const file = path.join(root, decodeURIComponent(req.url.split('?')[0]));
  if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': types[path.extname(file)] ?? 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
}).listen(0, '127.0.0.1');
await new Promise((r) => server.once('listening', r));
const port = server.address().port;

const fps = Number(process.argv[2] ?? 20);
const previews = process.argv[3]?.split(',').map(Number);
const browser = await chromium.launch({ channel: 'chrome', args: ['--use-angle=metal', '--enable-gpu'] });
const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
page.on('console', (m) => console.log('page:', m.text()));
page.on('pageerror', (e) => console.log('pageerror:', e.message));
await page.goto(`http://127.0.0.1:${port}/index.html`);
await page.waitForFunction(() => window.ready === true, null, { timeout: 30000 });

const out = path.join(root, previews ? 'previews' : 'frames');
fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out);
const duration = await page.evaluate(() => window.DURATION);
const times = previews ?? Array.from({ length: Math.round(duration * fps) }, (_, i) => i / fps);
for (const [i, t] of times.entries()) {
  await page.evaluate((t) => window.renderFrame(t), t);
  await page.locator('canvas').screenshot({ path: path.join(out, `f${String(i).padStart(4, '0')}.png`) });
}
console.log(`rendered ${times.length} frames to ${out}`);
await browser.close();
server.close();
