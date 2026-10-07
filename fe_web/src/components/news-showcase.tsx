"use client";

import { useMemo, useState } from "react";
import type { NewsPost } from "@/lib/types";

type MediaKind = "image" | "video";

function mediaUrl(path?: string | null): string | null {
  if (!path) return null;
  const cleanPath = path.replace(/^https?:\/\/[^/]+\/api/i, "");
  return `/api/backend${cleanPath.startsWith("/") ? cleanPath : `/${cleanPath}`}`;
}

function formatDate(value?: string | null): string {
  if (!value) return "Riset terbaru";
  return new Intl.DateTimeFormat("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  })
    .format(new Date(value))
    .toUpperCase();
}

export function NewsShowcase({ posts }: { posts: NewsPost[] }) {
  const [activeIndex, setActiveIndex] = useState(0);
  const [mediaKind, setMediaKind] = useState<MediaKind>("image");
  const activePost = posts[activeIndex];

  const availableMedia = useMemo(() => {
    if (!activePost) return [];
    const kinds: MediaKind[] = [];
    if (activePost.has_image && mediaUrl(activePost.image_url)) kinds.push("image");
    if (activePost.has_video && mediaUrl(activePost.video_url)) kinds.push("video");
    return kinds;
  }, [activePost]);

  if (!activePost) {
    return (
      <div className="news-empty">
        <span className="eyebrow">Research news</span>
        <h3>Publikasi sedang disiapkan</h3>
        <p>Berita riset yang sudah diterbitkan oleh admin akan tampil di sini.</p>
      </div>
    );
  }

  const resolvedMedia = availableMedia.includes(mediaKind)
    ? mediaKind
    : availableMedia[0];

  const selectPost = (index: number) => {
    setActiveIndex(index);
    setMediaKind(posts[index]?.has_image ? "image" : "video");
  };

  return (
    <div className="news-showcase">
      <article className="news-feature">
        <div className={`news-media news-media--${resolvedMedia ?? "empty"}`}>
          {resolvedMedia === "image" && (
            // This media is dynamic and streamed by Laravel through the same-origin BFF.
            // eslint-disable-next-line @next/next/no-img-element
            <img src={mediaUrl(activePost.image_url) ?? ""} alt={activePost.title} />
          )}
          {resolvedMedia === "video" && (
            <video
              src={mediaUrl(activePost.video_url) ?? ""}
              controls
              preload="metadata"
              playsInline
            >
              Browser Anda tidak mendukung video HTML5.
            </video>
          )}
          {!resolvedMedia && (
            <div className="news-media__placeholder" aria-hidden="true">
              <span>BRIN</span>
              <small>Research Publication</small>
            </div>
          )}

          {availableMedia.length > 1 && (
            <div className="media-switcher" aria-label="Pilih media">
              <button
                className={resolvedMedia === "image" ? "is-active" : ""}
                type="button"
                onClick={() => setMediaKind("image")}
              >
                Image
              </button>
              <button
                className={resolvedMedia === "video" ? "is-active" : ""}
                type="button"
                onClick={() => setMediaKind("video")}
              >
                Video
              </button>
            </div>
          )}
        </div>

        <div className="news-feature__copy">
          <div>
            <span className="eyebrow">{formatDate(activePost.published_at)}</span>
            <h3>{activePost.title}</h3>
            <p>{activePost.summary}</p>
          </div>
          <div className="news-feature__footer">
            <span>
              {String(activeIndex + 1).padStart(2, "0")} / {String(posts.length).padStart(2, "0")}
            </span>
            <div className="news-controls">
              <button
                type="button"
                aria-label="Berita sebelumnya"
                onClick={() => selectPost((activeIndex - 1 + posts.length) % posts.length)}
              >
                ←
              </button>
              <button
                type="button"
                aria-label="Berita berikutnya"
                onClick={() => selectPost((activeIndex + 1) % posts.length)}
              >
                →
              </button>
            </div>
          </div>
        </div>
      </article>

      {posts.length > 1 && (
        <div className="news-index" aria-label="Daftar berita riset">
          {posts.map((post, index) => (
            <button
              key={post.id}
              type="button"
              className={index === activeIndex ? "is-active" : ""}
              onClick={() => selectPost(index)}
            >
              <span>{String(index + 1).padStart(2, "0")}</span>
              <strong>{post.title}</strong>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
