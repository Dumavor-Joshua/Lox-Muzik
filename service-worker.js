const CACHE_NAME = "lox-muzik-shell-v64";
const APP_SHELL = [
  "./index.html?v=ep-upload-permissions-1",
  "./manifest.webmanifest",
  "./style.css?v=download-dialog-1",
  "./app.js?v=ep-upload-permissions-1",
  "./LOX-MUZIK_4000px_square.png",
  "./imgs/IMG-20261024-WA0040.jpg",
  "./imgs/welcome-radio.jpg",
  "./imgs/lox-muzik-download-cover.png",
];
const OPTIONAL_ASSETS = ["https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE_NAME)
    .then(async (cache) => {
      await cache.addAll(APP_SHELL);
      await Promise.allSettled(OPTIONAL_ASSETS.map((url) => cache.add(url)));
    })
    .then(() => self.skipWaiting()));
});

self.addEventListener("activate", (event) => {
  event.waitUntil(caches.keys()
    .then((cacheNames) => Promise.all(cacheNames
      .filter((cacheName) => cacheName.startsWith("lox-muzik-shell-") && cacheName !== CACHE_NAME)
      .map((cacheName) => caches.delete(cacheName))))
    .then(() => self.clients.claim()));
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;

  event.respondWith(caches.match(request, { ignoreSearch: true }).then((cachedResponse) => {
    if (cachedResponse) return cachedResponse;
    if (new URL(request.url).origin !== self.location.origin) return fetch(request);
    return fetch(request).catch((error) => {
      if (request.mode === "navigate") {
        return caches.match("./index.html", { ignoreSearch: true }).then((offlinePage) => {
          if (offlinePage) return offlinePage;
          throw error;
        });
      }
      throw error;
    });
  }));
});
