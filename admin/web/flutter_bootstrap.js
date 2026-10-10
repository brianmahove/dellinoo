// Custom Flutter bootstrap for the admin panel: no service worker.
//
// The default bootstrap registers Flutter's service worker, which caches the
// whole app and keeps serving the previous build until the browser happens to
// pick up the new one — so a fresh deploy looked "not deployed" (clicks worked
// but the URL never changed, because the old, pre-router build was still
// running). This is an internal tool on a fast connection with nothing to gain
// from offline caching, so it loads straight from the network instead.
//
// Any service worker a browser registered from an earlier build is unregistered
// here (and its caches dropped), so this only has to bite once per browser.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker
    .getRegistrations()
    .then((registrations) => Promise.all(registrations.map((r) => r.unregister())))
    .catch(() => {});
  if (window.caches) {
    caches
      .keys()
      .then((keys) => Promise.all(keys.map((k) => caches.delete(k))))
      .catch(() => {});
  }
}

{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load();
