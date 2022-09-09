let cache_name = "CocoNutsScouting";

self.addEventListener("fetch", event => {
    if (event.request.url === "https://mikejed.github.io/") {
        event.respondWith(
            fetch(event.request).catch(err =>
                self.cache.open(cache_name).then(cache => cache.match("/offline.html"))
            )
        );
    } else {
        event.respondWith(
            fetch(event.request).catch(err =>
                caches.match(event.request).then(response => response)
            )
        );
    }
});

self.addEventListener("fetch", event => {
    console.log("You fetched " + event.url);
});

const ASSETS = [
    "/CocoNuts-Scouting/Data%20Entry/qrcode.min.js",
    "/CocoNuts-Scouting/Data%20Entry/bootstrap.min.css",
    "/CocoNuts-Scouting/Data%20Entry/scoring-sheet.html",
    "/CocoNuts-Scouting/Data%20Entry/jquery-3.6.1.min.js"
];