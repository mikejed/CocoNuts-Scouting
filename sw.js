const cacheName = "CocoNutsScouting_2023-02-18_1";
const precacheResources = [
    "/CocoNuts-Scouting/",
    "/CocoNuts-Scouting/index.html",
    "/CocoNuts-Scouting/assets/qrcode.min.js",
    "/CocoNuts-Scouting/assets/bootstrap.min.css",
    "/CocoNuts-Scouting/assets/bootstrap.min.css.map",
    "/CocoNuts-Scouting/assets/jquery-3.6.1.min.js"
];

if ("serviceWorker" in navigator) {
  navigator.serviceWorker
  .register("sw.js")
  .then(() => console.log("Successfully registered service worker"));
}

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
    const response = await fetch(event.request);
    const cache = await caches.open(cacheName);

    cache.put(event.request, response.clone());
    return response;
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(cacheList => {
      return Promise.all(
        cacheList.filter(thisCache => {
          return thisCache.startsWith('CocoNutsScouting_') && thisCache !== cacheName;
        }).map(thisCache => {
          return caches.delete(thisCache);
        })
      );
    })
  );
});