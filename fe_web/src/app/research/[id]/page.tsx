import Link from "next/link";
import { notFound } from "next/navigation";
import { ApiError, apiRequest } from "@/lib/api";
import type { ApiEnvelope, NewsPost } from "@/lib/types";
import { NewsShowcase } from "@/components/news-showcase";

export default async function ResearchArticle({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!/^\d+$/.test(id)) notFound();
  let post: NewsPost;
  try {
    const response = await apiRequest<ApiEnvelope<NewsPost>>(`/news/${id}`, { cache: "no-store" });
    post = response.data;
  } catch (error) { if (error instanceof ApiError && error.status === 404) notFound(); throw error; }
  return <main className="research-article">
    <Link className="text-link" href="/#research">← Back to research news</Link>
    <article><span className="eyebrow">Research news</span><h1>{post.title}</h1>
      {post.published_at && <time dateTime={post.published_at}>{new Intl.DateTimeFormat("en-GB", { dateStyle: "long", timeZone: "Asia/Jakarta" }).format(new Date(post.published_at))}</time>}
      <p className="research-article__summary">{post.summary}</p>
      {(post.has_image || post.has_video) && <div className="research-article__media"><NewsShowcase posts={[post]} /></div>}
      <div className="research-article__body">{(post.body?.trim() || post.summary).split(/\n\s*\n/).map((paragraph, index) => <p key={index}>{paragraph}</p>)}</div>
    </article>
  </main>;
}
