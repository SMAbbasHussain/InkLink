/**
 * LOCAL TESTING ONLY. Serves AI images written by the Functions emulator
 * (AI_LOCAL_STORAGE=true) so a phone can load them.
 *
 *   node scripts/serve_local_ai_images.js            (port 5005)
 *
 * Only GET /ai-images/{boardId}/{generationId}.png is served; nothing else.
 * Binds to 127.0.0.1, so the phone reaches it through `adb reverse tcp:5005 tcp:5005`.
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { localStorageDir } = require('../src/ai/ai_storage_utils');

const PORT = Number(process.env.AI_LOCAL_IMAGE_PORT || 5005);
const DIR = localStorageDir();
const ROUTE = /^\/ai-images\/([A-Za-z0-9_-]{1,128})\/([A-Za-z0-9_-]{1,128})\.png$/;

const server = http.createServer((req, res) => {
  const match = ROUTE.exec((req.url || '').split('?')[0]);
  if (req.method !== 'GET' || !match) {
    res.writeHead(404);
    res.end();
    return;
  }
  const file = path.join(DIR, 'ai-images', match[1], `${match[2]}.png`);
  fs.readFile(file, (error, data) => {
    if (error) {
      res.writeHead(404);
      res.end();
      console.log(`404 ${req.url}`);
      return;
    }
    res.writeHead(200, { 'Content-Type': 'image/png', 'Cache-Control': 'no-store' });
    res.end(data);
    console.log(`200 ${req.url}`);
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Serving local AI images from ${DIR}`);
  console.log(`http://127.0.0.1:${PORT}/ai-images/...  (Ctrl+C to stop)`);
});
