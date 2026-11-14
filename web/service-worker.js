const CACHE_NAME = 'monazzem-pwa-v1';
const APP_SHELL = [
  new URL('./', self.registration.scope).href,
  new URL('index.html', self.registration.scope).href,
  new URL('manifest.json', self.registration.scope).href,
  new URL('favicon.png', self.registration.scope).href,
  new URL('icons/Icon-192.png', self.registration.scope).href,
  new URL('icons/Icon-512.png', self.registration.scope).href,
  new URL('icons/Icon-maskable-192.png', self.registration.scope).href,
  new URL('icons/Icon-maskable-512.png', self.registration.scope).href,
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys
          .filter((key) => key.startsWith('monazzem-pwa-') && key !== CACHE_NAME)
          .map((key) => caches.delete(key)),
      ))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) {
    return;
  }

  event.respondWith(
    fetch(request).then((response) => {
        if (!response.ok || response.type !== 'basic') return response;
        return caches.open(CACHE_NAME)
          .then((cache) => cache.put(request, response.clone()))
          .then(() => response);
      }).catch((error) => caches.match(request).then((cached) => {
        if (cached) return cached;
        if (request.mode === 'navigate') {
          return caches.match(new URL('./', self.registration.scope));
        }
        throw error;
      })),
  );
});
