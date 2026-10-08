"use client";

import Link from "next/link";

export default function ErrorPage({ reset }: { reset: () => void }) {
  return <main className="public-form-page"><section className="auth-card"><h2>Temporarily unavailable</h2><p>We could not load the workspace. Please try again in a moment.</p><div className="module-actions"><button className="button button--primary" onClick={reset}>Try again</button><Link className="button button--secondary" href="/login">Back to login</Link></div></section></main>;
}
