"use client";

import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react';
import { backend } from '@/lib/client-api';
import { hashModelFile, transferModel, type ModelControl, type ModelManifest, type ModelSession } from '@/lib/model-upload';

const control: ModelControl = async (path, method = 'GET', data, signal) => (await backend(path, method, data, signal)).data as ModelSession;
const labels: Record<string, string> = {uploading: 'Mengunggah', uploaded: 'Byte lengkap', validating: 'Memvalidasi',
  ready_for_test: 'Siap uji kompatibilitas', ready_for_activate: 'Siap publikasi / aktivasi', active: 'Aktif', cancelled: 'Dibatalkan', failed: 'Validasi gagal'};

export function ModelUploadForm() {
  const [sessions, setSessions] = useState<ModelSession[]>([]);
  const [session, setSession] = useState<ModelSession>();
  const [file, setFile] = useState<File>();
  const [busy, setBusy] = useState(false);
  const [transferring, setTransferring] = useState(false);
  const [phase, setPhase] = useState('');
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState('');
  const abort = useRef<AbortController | null>(null);
  const selectionRevision = useRef(0);
  const listRevision = useRef(0);
  const creation = useRef<{manifest: string; key: string} | null>(null);
  const [selectedId, setSelectedId] = useState<number>();
  const [selecting, setSelecting] = useState(false);
  const [page, setPage] = useState(1);
  const [pagination, setPagination] = useState({current_page: 1, last_page: 1});
  const [query, setQuery] = useState('');
  const [search, setSearch] = useState('');
  const [listing, setListing] = useState(false);

  const reload = useCallback(async (signal?: AbortSignal) => {
    const revision = ++listRevision.current;
    setListing(true);
    try {
      const result = await backend(`/admin/model-uploads?page=${page}&search=${encodeURIComponent(search)}`, 'GET', undefined, signal);
      if (revision === listRevision.current && !signal?.aborted) {
        setSessions(result.data as ModelSession[]);
        setPagination(result.pagination ?? {current_page: page, last_page: page});
      }
    } finally { if (revision === listRevision.current && !signal?.aborted) setListing(false); }
  }, [page, search]);
  useEffect(() => {
    const controller = new AbortController();
    void Promise.resolve().then(() => reload(controller.signal)).catch(() => { if (!controller.signal.aborted) setError('Daftar sesi belum dapat dimuat.'); });
    return () => controller.abort();
  }, [reload]);
  useEffect(() => () => { abort.current?.abort(); selectionRevision.current++; }, []);
  useEffect(() => {
    if (!session?.id) return;
    let cancelled = false;
    const revision = selectionRevision.current;
    const timer = setInterval(() => {
      void control(`/admin/model-uploads/${session.id}`).then(fresh => { if (!cancelled && revision === selectionRevision.current) setSession(fresh); })
        .catch(reason => { if (!cancelled && revision === selectionRevision.current) setError(String(reason.message)); });
    }, 3000);
    return () => { cancelled = true; clearInterval(timer); };
  }, [session?.id]);

  async function action(name: string) {
    if (!session) return;
    setBusy(true); setError('');
    try { setSession(await control(`/admin/model-uploads/${session.id}/${name}`, 'POST', {})); await reload(); }
    catch (reason) { setError(reason instanceof Error ? reason.message : 'Operasi gagal.'); }
    finally { setBusy(false); }
  }

  async function upload(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!file) { setError('Pilih ulang file bobot untuk memverifikasi SHA256 sebelum melanjutkan.'); return; }
    const fields = new FormData(event.currentTarget);
    const controller = new AbortController(); abort.current = controller;
    setBusy(true); setTransferring(true); setError(''); setProgress(0); setPhase('Menghitung SHA256');
    try {
      let current = session;
      if (!current) {
        const digest = await hashModelFile(file, setProgress, controller.signal);
        const manifest: ModelManifest = {schema_version: 1, model_id: String(fields.get('model_id')), version: String(fields.get('version')),
          name: String(fields.get('name')), description: String(fields.get('description')), framework: 'tensorflow', adapter: 'ginet-tcd-v1',
          weight_file: /\.h5$/i.test(file.name) ? 'model.h5' : 'model.keras', sha256: digest, size_bytes: file.size,
          input: {width: 1024, height: 1024, dtype: 'uint16', time_scalar: 0.5}};
        const identity = JSON.stringify(manifest);
        if (creation.current?.manifest !== identity) creation.current = {manifest: identity, key: crypto.randomUUID()};
        current = await control('/admin/model-uploads', 'POST', {...manifest, creation_key: creation.current.key}, controller.signal);
        setSelectedId(current.id); setSession(current); await reload();
      }
      const completed = await transferModel(file, current, {control, signal: controller.signal,
        hashing: value => { setPhase('Memverifikasi SHA256'); setProgress(value); },
        progress: value => { setPhase('Mengunggah langsung ke TUF'); setProgress(value); }});
      setSession(completed); setPhase('Upload selesai');
    } catch (reason) { setError(controller.signal.aborted ? 'Upload dijeda. Pilih ulang file yang sama untuk melanjutkan.' : reason instanceof Error ? reason.message : 'Upload gagal.'); }
    finally { setBusy(false); setTransferring(false); abort.current = null; }
  }

  return <section className="module-panel model-upload-panel" aria-labelledby="model-upload-title">
    <h2 id="model-upload-title">Upload bobot model ke TUF</h2>
    <p>Format .h5 / .keras, maksimum 10 GiB. Adapter GINet TC-D disetujui. Publikasi menyimpan versi; aktivasi dilakukan terpisah.</p>
    <label>Cari sesi model / versi<input maxLength={80} value={query} onChange={event => setQuery(event.target.value)} /></label>
    <div className="module-actions">
      <button disabled={busy || listing} onClick={() => { setPage(1); setSearch(query); }}>Cari sesi</button>
      <button disabled={busy || listing || page <= 1} onClick={() => setPage(page - 1)}>Sesi sebelumnya</button>
      <span>Halaman {pagination.current_page} / {pagination.last_page}</span>
      <button disabled={busy || listing || page >= pagination.last_page} onClick={() => setPage(page + 1)}>Sesi berikutnya</button>
    </div>
    <label>Sesi tersimpan<select disabled={busy} value={selectedId ?? ''} onChange={event => {
      const id = event.target.value ? Number(event.target.value) : undefined;
      const revision = ++selectionRevision.current;
      setSelectedId(id); setSession(undefined); setSelecting(id !== undefined);
      setFile(undefined); setPhase(''); setError('');
      if (id !== undefined) void control(`/admin/model-uploads/${id}`).then(fresh => {
        if (revision === selectionRevision.current) setSession(fresh);
      }).catch(reason => { if (revision === selectionRevision.current) setError(reason.message); })
        .finally(() => { if (revision === selectionRevision.current) setSelecting(false); });
    }}><option value="">Versi baru</option>{[...sessions, ...(session && !sessions.some(item => item.id === session.id) ? [session] : [])].map(item => <option value={item.id} key={item.id}>{item.manifest.model_id} / {item.manifest.version} — {labels[item.state] ?? item.state}</option>)}</select></label>
    {selecting && <p role="status">Memuat sesi terpilih…</p>}
    <form className="module-form" onSubmit={upload} key={session?.id ?? selectedId ?? 'new'}>
      <label><span>ID model</span><input name="model_id" required pattern="[a-z0-9]+(-[a-z0-9]+)*" maxLength={80} readOnly={!!session || selecting} defaultValue={session?.manifest.model_id} /></label>
      <label><span>Versi immutable (contoh 1.0.0)</span><input name="version" required pattern="(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)" readOnly={!!session || selecting} defaultValue={session?.manifest.version} /></label>
      <label><span>Nama tampilan</span><input name="name" required maxLength={160} readOnly={!!session || selecting} defaultValue={session?.manifest.name} /></label>
      <label><span>Deskripsi</span><textarea name="description" maxLength={4000} readOnly={!!session || selecting} defaultValue={session?.manifest.description} /></label>
      {(!session || ['uploading', 'uploaded'].includes(session.state)) && <>
        <label><span>{session ? 'Pilih ulang file yang sama untuk resume' : 'File bobot'}</span><input type="file" accept=".h5,.keras" disabled={busy || selecting} onChange={event => setFile(event.target.files?.[0])} /></label>
        <button className="button button--primary" disabled={busy || selecting || !file}>{session ? 'Verifikasi & lanjutkan' : 'Hash & upload'}</button>
      </>}
    </form>
    {phase && <div role="status"><p>{phase} · {progress}%</p><progress max={100} value={progress} aria-label={phase} /></div>}
    {session && <p role="status">{labels[session.state] ?? session.state}{session.operation ? ` · ${session.operation} sedang berjalan` : ''} · {(session.offset / 1024 ** 2).toFixed(1)} MiB diterima</p>}
    {session?.last_error && <p role="alert">Operasi belum berhasil ({session.last_error}). Periksa kapasitas/format lalu ulangi.</p>}
    {error && <p className="form-message form-message--error" role="alert">{error}</p>}
    <div className="module-actions">
      {transferring && <button className="button button--secondary" onClick={() => abort.current?.abort()}>Jeda upload</button>}
      {session && !session.operation && <>
        {session.state === 'uploaded' && <button disabled={busy} onClick={() => void action('finalize')}>Validasi manifest & format</button>}
        {session.state === 'ready_for_test' && <button disabled={busy} onClick={() => void action('test')}>Uji kompatibilitas GPU</button>}
        {session.state === 'ready_for_activate' && !session.published && <button disabled={busy} onClick={() => void action('publish')}>Publikasikan versi nonaktif</button>}
        {session.state === 'ready_for_activate' && session.published && <button disabled={busy} onClick={() => void action('activate')}>Aktifkan versi</button>}
        {session.state === 'active' && <button disabled={busy} onClick={() => void action('deactivate')}>Nonaktifkan versi</button>}
        {!session.published && !['cancelled', 'failed'].includes(session.state) && <button disabled={busy} onClick={() => void action('cancel')}>Batalkan sesi</button>}
      </>}
      <button disabled={busy} onClick={async () => { try { await backend('/admin/model-uploads/sync', 'POST', {}); await reload(); } catch (reason) { setError(reason instanceof Error ? reason.message : 'Sinkronisasi gagal.'); } }}>Sinkronisasi katalog TUF</button>
    </div>
    <p>Uji kompatibilitas memeriksa format, bentuk, dan runtime; hasilnya bukan validasi ilmiah. Kapasitas GPU diperlukan dan versi lama tetap tersedia untuk rollback.</p>
  </section>;
}
