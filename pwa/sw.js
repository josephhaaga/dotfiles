// Service worker — cache shell for offline PWA install
// Strategy: network-first for /api/services, cache-first for shell assets

const CACHE = 'dev-home-v1';
const SHELL = ['/', '/manifest.json', '/icon.svg'];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);

  // Always network for API
  if (url.pathname.startsWith('/api/')) {
    e.respondWith(fetch(e.request));
    return;
  }

  // Cache-first for shell
  e.respondWith(
    caches.match(e.request).then(cached => cached ?? fetch(e.request))
  );
});
