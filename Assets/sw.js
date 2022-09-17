const cacheName = "CocoNutsScouting";
const precacheResources = [
    "/",
    "/CocoNuts-Scouting/index.html",
    "/CocoNuts-Scouting/Assets/qrcode.min.js",
    "/CocoNuts-Scouting/Assets/bootstrap.min.css",
    "/CocoNuts-Scouting/Assets/jquery-3.6.1.min.js"
];

// install event handler (note async operation)
// opens named cache, pre-caches identified resources above
self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(cacheName);
    cache.addAll(precacheResources);
  })());
});

self.addEventListener('activate', event => {
  console.log('Service worker activate event!');
});

// When there's an incoming fetch request, try and respond with a precached resource, otherwise fall back to the network
self.addEventListener('fetch', event => {
  event.respondWith((async () => {
    const cache = await caches.open(cacheName);

    // Try the cache first.
    const cachedResponse = await cache.match(event.request);
    if (cachedResponse !== undefined) {
      // Cache hit, let's send the cached resource.
      return cachedResponse;
    } else {
      // Nothing in cache, let's go to the network.
      return fetch(event.request);
    }
  }
});
