const DOWNLOAD_PATH = /^\/api\/backend\/predictions\/(\d+)\/download\/(results|complete)$/;
const START_TIMEOUT = 30_000;

/** Accept only the relative, owner-scoped capability returned by Laravel. */
export function buildPredictionDownload(base: string, path: unknown, id: string, kind: string) {
  if (!/^\d+$/.test(id) || !/^(results|complete)$/.test(kind) || typeof path !== "string") throw new Error("Invalid download link.");
  const expected = `/api/downloads/predictions/${id}/${kind}`;
  const [pathname, query, extra] = path.split("?");
  const params = new URLSearchParams(query);
  if (pathname !== expected || extra !== undefined || !query ||
      params.size !== 3 || !/^\d+$/.test(params.get("owner") ?? "") || !/^\d+$/.test(params.get("expires") ?? "") ||
      !/^[a-f0-9]{64}$/.test(params.get("signature") ?? "") ||
      Number(params.get("expires")) * 1000 <= Date.now()) throw new Error("Invalid download link.");
  const api = new URL(base.replace(/\/+$/, ""));
  if (!/^https?:$/.test(api.protocol) || api.username || api.password || api.search || api.hash || !api.pathname.endsWith("/api")) throw new Error("Invalid API URL.");
  return { url: `${api.origin}${api.pathname.slice(0, -4)}${path}`, filename: `${kind}_${id}.zip` };
}

function bounded<T>(promise: Promise<T>, message: string): Promise<T> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(message)), START_TIMEOUT);
    promise.then(value => { clearTimeout(timer); resolve(value); }, error => { clearTimeout(timer); reject(error); });
  });
}

let workerReady: Promise<ServiceWorker> | undefined;
let downloadFrame: HTMLIFrameElement | undefined;
function downloadWorker(): Promise<ServiceWorker> {
  if (!workerReady) {
    workerReady = bounded((async () => {
      const registration = await navigator.serviceWorker.register("/prediction-download-sw.js", { scope: "/" });
      await navigator.serviceWorker.ready;
      if (registration.active?.state !== "activated") {
        const worker = registration.installing ?? registration.waiting ?? registration.active;
        if (!worker) throw new Error("Download worker could not start.");
        await new Promise<void>((resolve, reject) => {
          const changed = () => {
            if (worker.state === "activated") { worker.removeEventListener("statechange", changed); resolve(); }
            if (worker.state === "redundant") { worker.removeEventListener("statechange", changed); reject(new Error("Download worker could not start.")); }
          };
          worker.addEventListener("statechange", changed); changed();
        });
      }
      if (!registration.active) throw new Error("Download worker could not start.");
      // Activation and claim() are distinct: on a first visit the page may not
      // yet be controlled when the active worker becomes available.
      if (navigator.serviceWorker.controller !== registration.active) {
        await new Promise<void>(resolve => {
          const claimed = () => {
            if (navigator.serviceWorker.controller === registration.active) {
              navigator.serviceWorker.removeEventListener("controllerchange", claimed);
              resolve();
            }
          };
          navigator.serviceWorker.addEventListener("controllerchange", claimed); claimed();
        });
      }
      return registration.active;
    })(), "Download worker startup timed out.").catch(error => { workerReady = undefined; throw error; });
  }
  return workerReady;
}

/** Resolve when the browser begins receiving a validated archive stream. */
export async function startPredictionDownload(path: string): Promise<void> {
  const match = DOWNLOAD_PATH.exec(path);
  if (!match) throw new Error("Invalid prediction download path.");
  if (typeof navigator === "undefined" || !("serviceWorker" in navigator) || typeof MessageChannel === "undefined") throw new Error("This browser cannot start the download worker.");
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), START_TIMEOUT);
  let payload;
  try {
    const response = await fetch(`${path}?prepare=1`, { credentials: "same-origin", cache: "no-store", signal: controller.signal, headers: { accept: "application/json" } });
    payload = await response.json();
    if (!response.ok || payload?.success !== true) throw new Error(payload?.message || "Unable to prepare download.");
  } finally { clearTimeout(timer); }
  const { url, filename } = payload?.data ?? {};
  if (typeof url !== "string" || filename !== `${match[2]}_${match[1]}.zip`) throw new Error("Invalid download response.");
  const worker = await downloadWorker();
  const channel = new MessageChannel();
  try {
    await bounded(new Promise<void>((resolve, reject) => {
      let registered = false;
      channel.port1.onmessage = ({ data }) => {
        if (data?.type === "error") { reject(new Error(data.message || "Unable to start download.")); return; }
        if (data?.type === "started" && registered) { resolve(); return; }
        if (data?.type !== "registered" || registered || typeof data.path !== "string" || !/^\/__prediction-download\/[a-f0-9]{64}$/.test(data.path)) return;
        registered = true;
        // A failed navigation must not replace the application page. Reuse one
        // hidden browsing context; attachment responses stream to the browser.
        if (!downloadFrame?.isConnected) {
          downloadFrame = document.createElement("iframe");
          downloadFrame.name = "prediction-download-target";
          downloadFrame.hidden = true;
          downloadFrame.title = "Prediction archive download";
          document.body.append(downloadFrame);
        }
        const anchor = document.createElement("a");
        // Let the worker's attachment header trigger the browser download.
        // Chromium can bypass fetch interception for anchors with download=.
        anchor.href = data.path; anchor.target = downloadFrame.name; anchor.hidden = true;
        document.body.append(anchor); anchor.click(); anchor.remove();
      };
      worker.postMessage({ type: "REGISTER_PREDICTION_DOWNLOAD", url, filename }, [channel.port2]);
    }), "Download did not start. Please try again.");
  } finally { channel.port1.close(); }
}
