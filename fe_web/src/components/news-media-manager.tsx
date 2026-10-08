"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";
import { Modal } from "@/components/modal";
import { asRow, backend, bytes, uploadArchive, type Row } from "@/lib/client-api";

export function NewsMediaManager({ post, onClose, onChanged }: {
  post: Row; onClose: () => void; onChanged: () => Promise<void>;
}) {
  const [current, setCurrent] = useState(post);
  const [busy, setBusy] = useState<"image" | "video" | null>(null);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [progress, setProgress] = useState<number>();
  const [revision, setRevision] = useState(0);
  const [selectedImage, setSelectedImage] = useState<File>();
  const [selectedVideo, setSelectedVideo] = useState<File>();
  const [preview, setPreview] = useState("");
  const controller = useRef<AbortController | null>(null);

  useEffect(() => () => controller.current?.abort(), []);
  useEffect(() => {
    if (!selectedImage) return;
    const url = URL.createObjectURL(selectedImage);
    void Promise.resolve().then(() => setPreview(url));
    return () => URL.revokeObjectURL(url);
  }, [selectedImage]);

  async function reload(message: string) {
    const response = await backend(`/admin/news/${post.id}`);
    setCurrent(asRow(response.data));
    setRevision(Date.now());
    setNotice(message);
    await onChanged();
  }

  async function uploadImage(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedImage) return;
    if (!["image/jpeg", "image/png", "image/webp"].includes(selectedImage.type) || selectedImage.size > 3 * 1024 * 1024) {
      setError("Choose a JPEG, PNG or WebP image up to 3 MB."); return;
    }
    const form = event.currentTarget;
    setBusy("image"); setError(""); setNotice("");
    try {
      const data = new FormData(); data.set("image", selectedImage);
      await backend(`/admin/news/${post.id}`, "POST", data);
      await reload("Image saved. Your video and article are unchanged.");
      setSelectedImage(undefined); setPreview(""); form.reset();
    } catch (reason) { setError(reason instanceof Error ? reason.message : "Unable to save image."); }
    finally { setBusy(null); }
  }

  async function uploadVideo(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedVideo) return;
    if (!/\.(mp4|webm)$/i.test(selectedVideo.name) || selectedVideo.size > 50 * 1024 * 1024) {
      setError("Choose an MP4 or WebM video up to 50 MB."); return;
    }
    const form = event.currentTarget;
    const abort = new AbortController(); controller.current = abort;
    setBusy("video"); setError(""); setNotice(""); setProgress(0);
    try {
      await uploadArchive(selectedVideo, { purpose: "news_video", news_post_id: post.id }, setProgress, abort.signal);
      await reload("Video saved. Your image and article are unchanged.");
      setSelectedVideo(undefined); form.reset();
    } catch (reason) {
      setError(abort.signal.aborted ? "Video upload paused. Click Upload video to resume the same file." : reason instanceof Error ? reason.message : "Unable to save video. Retry to resume.");
    } finally { setBusy(null); setProgress(undefined); controller.current = null; }
  }

  async function remove(kind: "image" | "video") {
    if (!window.confirm(`Remove this ${kind} from the article?`)) return;
    setBusy(kind); setError(""); setNotice("");
    try {
      await backend(`/admin/news/${post.id}`, "POST", { [`remove_${kind}`]: true });
      await reload(`${kind === "image" ? "Image" : "Video"} removed.`);
    } catch (reason) { setError(reason instanceof Error ? reason.message : "Unable to remove media."); }
    finally { setBusy(null); }
  }

  return <Modal labelledBy="news-media-title" onClose={onClose} busy={busy !== null}>
    <header className="media-manager__header">
      <div><span className="eyebrow">Research news</span><h2 id="news-media-title">Manage media</h2><p>{String(post.title)}</p></div>
      <button className="button button--secondary" disabled={busy !== null} onClick={onClose}>Close</button>
    </header>
    <p className="module-note">Choose the image and video independently. Each upload updates only its own media.</p>
    {error && <p className="form-message form-message--error" role="alert">{error}</p>}
    {notice && <p className="form-message form-message--success" role="status">{notice}</p>}
    <div className="news-media-grid">
      <section className="news-media-card" aria-labelledby="news-image-title">
        <div><span className="media-step">01 · Image</span><h3 id="news-image-title">Article image</h3><p>JPEG, PNG or WebP · up to 3 MB</p></div>
        <div className="news-media-card__preview">
          {(selectedImage && preview) || current.has_image === true ?
            // Dynamic protected media and a local object URL cannot use the Next image optimizer.
            // eslint-disable-next-line @next/next/no-img-element
            <img src={selectedImage && preview ? preview : `/api/backend/news/${post.id}/image?v=${revision}`} alt={selectedImage ? "Selected article image" : String(post.title)} />
            : <p>No image yet<br /><small>Add a photo or research illustration.</small></p>}
        </div>
        <form className="module-form" onSubmit={uploadImage}>
          <label className="media-file-picker"><span>Choose image</span><input name="image" type="file" accept="image/jpeg,image/png,image/webp" disabled={busy !== null} required onChange={(event) => setSelectedImage(event.target.files?.[0])} /></label>
          {selectedImage && <small className="media-file-summary">{selectedImage.name} · {bytes(selectedImage.size)}</small>}
          <div className="module-actions"><button className="button button--primary" disabled={busy !== null || !selectedImage}>{busy === "image" ? "Saving image…" : "Upload image"}</button>
            {current.has_image === true && <button className="button button--secondary danger-action" type="button" disabled={busy !== null} onClick={() => void remove("image")}>Remove image</button>}</div>
        </form>
      </section>
      <section className="news-media-card" aria-labelledby="news-video-title">
        <div><span className="media-step">02 · Video</span><h3 id="news-video-title">Research video</h3><p>MP4 or WebM · up to 50 MB</p></div>
        <div className="news-media-card__preview">
          {current.has_video === true ? <video src={`/api/backend/news/${post.id}/video?v=${revision}`} controls playsInline preload="metadata" /> : <p>No video yet<br /><small>Add a demonstration or research update.</small></p>}
        </div>
        <form className="module-form" onSubmit={uploadVideo}>
          <label className="media-file-picker"><span>Choose video</span><input name="video" type="file" accept="video/mp4,video/webm" disabled={busy !== null} required onChange={(event) => setSelectedVideo(event.target.files?.[0])} /></label>
          {selectedVideo && <small className="media-file-summary">{selectedVideo.name} · {bytes(selectedVideo.size)}</small>}
          {progress !== undefined && <div role="status" className="media-upload-progress"><progress max={100} value={progress} /><span>Uploading video · {progress}%</span></div>}
          <div className="module-actions"><button className="button button--primary" disabled={busy !== null || !selectedVideo}>{busy === "video" ? "Uploading video…" : "Upload video"}</button>
            {busy === "video" && <button className="button button--secondary" type="button" onClick={() => controller.current?.abort()}>Pause upload</button>}
            {current.has_video === true && <button className="button button--secondary danger-action" type="button" disabled={busy !== null} onClick={() => void remove("video")}>Remove video</button>}</div>
        </form>
      </section>
    </div>
  </Modal>;
}
