const cacheName = "CocoNutsScouting-2023-01-30-1";
const precacheResources = [
    "/CocoNuts-Scouting/",
    "/CocoNuts-Scouting/index.html",
    "/CocoNuts-Scouting/assets/qrcode.min.js",
    "/CocoNuts-Scouting/assets/bootstrap.min.css",
    "/CocoNuts-Scouting/assets/bootstrap.min.css.map",
    "/CocoNuts-Scouting/assets/jquery-3.6.1.min.js"
];

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(cacheName);
    await cache.addAll(precacheResources);
  })());
});

self.addEventListener('fetch', (event) => {
  event.respondWith((async () => {
    // try the cache first
    const r = await caches.match(event.request);
    if (r) { return r; }

    // cache the new resource and return it
    const response = await fetch(e.request);
    const cache = await caches.open(cacheName);

    cache.put(e.request, response.clone());
    return response;
  })());
});
