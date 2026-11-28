// Minimal service worker for installability.
//
// Browsers only offer to install a site whose service worker handles fetch,
// so this worker exists for that, not for offline caching: the canvas needs
// the network and a stale app shell would silently ship old code. Requests are
// always network-first; the only fallback is a readable offline page for
// navigations.
const OFFLINE = new Response(
  '<!doctype html><meta charset="utf-8"><title>InkLink is offline</title>' +
    '<body style="font-family:system-ui;padding:32px;color:#0B0B0F">' +
    '<h1>InkLink is offline</h1>' +
    '<p>Reconnect to the internet and reload to keep working on your boards.</p>',
  { status: 503, headers: { 'Content-Type': 'text/html; charset=utf-8' } },
);

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  if (new URL(request.url).origin !== self.location.origin) return;

  event.respondWith(
    fetch(request).catch(() =>
      request.mode === 'navigate' ? OFFLINE : Response.error(),
    ),
  );
});
