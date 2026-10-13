import { sha256 } from '@noble/hashes/sha2.js';

export const CHUNK_BYTES = 4 * 1024 ** 2;
export const MAX_MODEL_BYTES = 10 * 1024 ** 3;
export type ModelManifest = { schema_version: number; model_id: string; version: string; name: string; description: string;
  framework: string; adapter: string; weight_file: string; sha256: string; size_bytes: number;
  input: {width: number; height: number; dtype: string; time_scalar: number} };
export type ModelSession = { id: number; manifest: ModelManifest; state: string; offset: number; upload_url: string;
  token?: string; expires_at?: number; published: boolean; operation?: string; last_error?: string; compatibility?: string };
export type ModelControl = (path: string, method?: string, data?: Record<string, unknown>, signal?: AbortSignal) => Promise<ModelSession>;

export async function validateModelFile(file: File) {
  if (!/\.(h5|keras)$/i.test(file.name)) throw new Error('Pilih bobot .h5 atau .keras.');
  if (!file.size || file.size > MAX_MODEL_BYTES) throw new Error('Ukuran model harus 1 byte–10 GiB.');
  const signature = new Uint8Array(await file.slice(0, 8).arrayBuffer());
  const valid = /\.h5$/i.test(file.name)
    ? [137, 72, 68, 70, 13, 10, 26, 10].every((n, i) => signature[i] === n)
    : signature[0] === 80 && signature[1] === 75 && signature[2] === 3 && signature[3] === 4;
  if (!valid) throw new Error('Format file tidak sesuai dengan .h5/.keras.');
}

export async function hashModelFile(file: File, progress: (value: number) => void, signal?: AbortSignal): Promise<string> {
  await validateModelFile(file);
  const hash = sha256.create();
  try {
    for (let offset = 0; offset < file.size; offset += CHUNK_BYTES) {
      signal?.throwIfAborted();
      hash.update(new Uint8Array(await file.slice(offset, Math.min(file.size, offset + CHUNK_BYTES)).arrayBuffer()));
      progress(Math.round(Math.min(file.size, offset + CHUNK_BYTES) / file.size * 100));
    }
    return Array.from(hash.digest(), value => value.toString(16).padStart(2, '0')).join('');
  } finally { hash.destroy(); }
}

function secureUploadUrl(value: string) {
  const url = new URL(value);
  if (url.protocol !== 'https:' || url.username || url.password || url.hash) throw new Error('HTTPS upload URL required.');
  return url.href;
}

export async function transferModel(file: File, original: ModelSession, options: {
  control: ModelControl; direct?: typeof fetch; progress: (value: number) => void;
  hashing?: (value: number) => void; signal?: AbortSignal;
}): Promise<ModelSession> {
  secureUploadUrl(original.upload_url);
  // Always rehash a newly selected file before resume; filenames are not identity.
  const digest = await hashModelFile(file, options.hashing ?? (() => {}), options.signal);
  if (digest !== original.manifest.sha256 || file.size !== original.manifest.size_bytes
      || !file.name.toLowerCase().endsWith(original.manifest.weight_file.slice(5))) throw new Error('File identity/digest differs from this upload session.');
  const path = `/admin/model-uploads/${original.id}`;
  const checked = (session: ModelSession) => {
    if (session.id !== original.id || session.manifest.sha256 !== digest || session.manifest.size_bytes !== file.size
        || session.manifest.weight_file !== original.manifest.weight_file) throw new Error('Session identity/digest changed.');
    if (!Number.isSafeInteger(session.offset) || session.offset < 0 || session.offset > file.size) throw new Error('Invalid server offset.');
    if (session.state !== 'uploading' && session.state !== 'uploaded') throw new Error('Sesi tidak menerima byte lagi.');
    return session;
  };
  let session = checked(await options.control(path, 'GET', undefined, options.signal));
  if (session.offset < file.size) session = checked(await options.control(`${path}/renew`, 'POST', {}, options.signal));
  let retries = 0;
  while (session.offset < file.size) {
    options.signal?.throwIfAborted();
    const offset = session.offset;
    if (!Number.isSafeInteger(offset) || offset < 0 || !session.token) throw new Error('Invalid upload session.');
    const chunk = file.slice(offset, Math.min(offset + CHUNK_BYTES, file.size));
    try {
      const response = await (options.direct ?? fetch)(secureUploadUrl(session.upload_url), {
        method: 'PUT', credentials: 'omit', redirect: 'error', signal: options.signal,
        headers: {'Authorization': `Bearer ${session.token}`, 'Upload-Offset': String(offset), 'Content-Type': 'application/octet-stream'}, body: chunk,
      });
      if (!response.ok) throw new Error(`Upload gagal (${response.status}); pilih ulang file untuk melanjutkan.`);
      const data = await response.json();
      if (data.offset !== offset + chunk.size) throw new Error('Invalid server offset.');
      session = {...session, offset: data.offset};
      retries = 0;
    } catch (error) {
      options.signal?.throwIfAborted();
      if (++retries > 3) throw error;
      // A lost response can mean bytes were committed. Ask Laravel/TUF before retry.
      session = checked(await options.control(path, 'GET', undefined, options.signal));
      if (session.offset < file.size) session = checked(await options.control(`${path}/renew`, 'POST', {}, options.signal));
    }
    options.progress(Math.round(session.offset / file.size * 100));
  }
  return {...session, state: 'uploaded'};
}
