/* global self */
// Capabilities stay in memory only; restarting the worker requires a new prepare.
const downloads = new Map();
const MAX_DOWNLOADS = 32;
const ROUTE = /^\/__prediction-download\/([a-f0-9]{64})$/;

self.addEventListener("install", event => event.waitUntil(self.skipWaiting()));
self.addEventListener("activate", event => event.waitUntil(self.clients.claim()));

function prune() {
  for (const [key, record] of downloads) if (record.expires <= Date.now()) downloads.delete(key);
}

self.addEventListener("message", event => {
  if (event.data?.type !== "REGISTER_PREDICTION_DOWNLOAD" || !event.ports[0]) return;
  const port = event.ports[0];
  event.waitUntil((async () => {
    try {
      const client = event.source?.id && await self.clients.get(event.source.id);
      if (!client || client.type !== "window" || new URL(client.url).origin !== self.location.origin) throw new Error("Invalid download client.");
      const { url, filename } = event.data;
      if (typeof url !== "string") throw new Error("Invalid download URL.");
      const target = new URL(url);
      const match = target.pathname.match(/^(?:\/[a-zA-Z0-9_-]+)*\/api\/downloads\/predictions\/(\d+)\/(results|complete)$/);
      const params = target.searchParams;
      const expires = Number(params.get("expires")) * 1000;
      if (!/^https?:$/.test(target.protocol) || target.username || target.password || target.hash ||
          !match || filename !== `${match[2]}_${match[1]}.zip` || params.size !== 3 || !/^\d+$/.test(params.get("owner") ?? "") ||
          !/^\d+$/.test(params.get("expires") ?? "") || !/^[a-f0-9]{64}$/.test(params.get("signature") ?? "") || expires <= Date.now()) throw new Error("Invalid signed download link.");
      prune();
      while (downloads.size >= MAX_DOWNLOADS) downloads.delete(downloads.keys().next().value);
      const handle = Array.from(crypto.getRandomValues(new Uint8Array(32)), byte => byte.toString(16).padStart(2, "0")).join("");
      downloads.set(handle, { url, filename, expires: Math.min(expires, Date.now() + 10 * 60_000), port });
      port.postMessage({ type: "registered", path: `/__prediction-download/${handle}` });
    } catch (error) { port.postMessage({ type: "error", message: error.message }); }
  })());
});

async function streamDownload(request, handle) {
  prune();
  const record = downloads.get(handle);
  if (!record) return Response.error();
  try {
    const headers = new Headers({ "ngrok-skip-browser-warning": "true", accept: "application/zip" });
    for (const name of ["range", "if-range"]) {
      const value = request.headers.get(name);
      if (value) headers.set(name, value);
    }
    const upstream = await fetch(record.url, { headers, credentials: "omit", redirect: "error", cache: "no-store" });
    const contentType = upstream.headers.get("content-type")?.split(";")[0].trim().toLowerCase();
    if (![200, 206].includes(upstream.status) || !upstream.body || !["application/zip", "application/x-zip-compressed"].includes(contentType)) {
      await upstream.body?.cancel();
      throw new Error("The archive server did not return a ZIP file. Please try again.");
    }
    const responseHeaders = new Headers({ "content-type": "application/zip", "content-disposition": `attachment; filename="${record.filename}"`, "cache-control": "no-store", "x-content-type-options": "nosniff" });
    for (const name of ["content-length", "content-range", "accept-ranges", "x-checksum-md5", "content-md5", "etag", "last-modified"]) {
      const value = upstream.headers.get(name);
      if (value) responseHeaders.set(name, value);
    }
    record.port.postMessage({ type: "started" });
    return new Response(upstream.body, { status: upstream.status, headers: responseHeaders });
  } catch {
    record.port.postMessage({ type: "error", message: "Unable to download the ZIP archive. Please try again." });
    // A network error prevents the browser saving an error page as a ZIP.
    return Response.error();
  }
}

self.addEventListener("fetch", event => {
  const url = new URL(event.request.url);
  const match = ROUTE.exec(url.pathname);
  if (url.origin !== self.location.origin || !match || url.search || event.request.method !== "GET") return;
  event.respondWith(streamDownload(event.request, match[1]));
});
