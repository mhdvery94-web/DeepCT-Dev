import Image from "next/image";
import Link from "next/link";
import { JoinForm } from "@/components/join-form";
import { NewsShowcase } from "@/components/news-showcase";
import { SiteHeader } from "@/components/site-header";
import { getPublishedNews } from "@/lib/api";

const features = [
  {
    number: "01",
    title: "High-fidelity analysis",
    description:
      "Validated neural architectures transform CT datasets into repeatable, reviewable research outputs.",
  },
  {
    number: "02",
    title: "Sanctioned environment",
    description:
      "Data and model access stay inside institutionally governed infrastructure with a complete activity trail.",
  },
  {
    number: "03",
    title: "Streamlined workflow",
    description:
      "Upload, queue, monitor, compare and export results from one focused workspace across desktop and mobile.",
  },
];

export default async function Home() {
  const posts = await getPublishedNews();

  return (
    <>
      <SiteHeader />
      <main>
        <section className="hero" id="home">
          <div className="page-shell hero__inner">
            <div className="hero__copy">
              <span className="eyebrow">BRIN research infrastructure</span>
              <h1>
                Advancing Indonesian research through <em>deep learning.</em>
              </h1>
              <p>
                A secure workspace for neutron and X-ray CT prediction, model training,
                and reproducible scientific analysis.
              </p>
              <div className="hero__actions">
                <a className="button button--primary" href="#research">
                  Explore research
                </a>
                <Link className="text-link" href="/login">
                  Open workspace <span aria-hidden="true">↗</span>
                </Link>
              </div>
              <dl className="hero__metrics">
                <div>
                  <dt>01</dt>
                  <dd>Unified research portal</dd>
                </div>
                <div>
                  <dt>24/7</dt>
                  <dd>Managed inference queue</dd>
                </div>
                <div>
                  <dt>100%</dt>
                  <dd>Auditable activity</dd>
                </div>
              </dl>
            </div>

            <div className="hero__visual" aria-label="Neutron CT research visualization">
              <div className="hero__visual-frame">
                <Image
                  src="/assets/icon.jpg"
                  alt="Computed tomography research visualization"
                  fill
                  sizes="(max-width: 900px) 100vw, 48vw"
                  priority
                />
              </div>
              <div className="hero__stamp">
                <Image src="/assets/BRIN.png" alt="" width={34} height={34} />
                <span>National Research<br />&amp; Innovation Agency</span>
              </div>
              <div className="hero__axis" aria-hidden="true">
                <span>X</span><span>Y</span><span>Z</span>
              </div>
            </div>
          </div>
        </section>

        <section className="section section--muted" id="about">
          <div className="page-shell">
            <div className="section-heading section-heading--split">
              <div>
                <span className="eyebrow">Platform capabilities</span>
                <h2>Built for serious research workflows.</h2>
              </div>
              <p>
                Access state-of-the-art models vetted for institutional use while
                keeping every dataset, decision and result traceable.
              </p>
            </div>
            <div className="feature-grid">
              {features.map((feature) => (
                <article className="feature-card" key={feature.number}>
                  <span>{feature.number}</span>
                  <h3>{feature.title}</h3>
                  <p>{feature.description}</p>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section className="section" id="research">
          <div className="page-shell">
            <div className="section-heading section-heading--split">
              <div>
                <span className="eyebrow">Latest research</span>
                <h2>Research stories in a focused media stage.</h2>
              </div>
              <p>
                Image and video share one responsive stage. On desktop the story stays
                alongside the media; on mobile it stacks into a focused reading flow.
              </p>
            </div>
            <NewsShowcase posts={posts} />
          </div>
        </section>

        <section className="section section--dark" id="join">
          <div className="page-shell join-layout">
            <div className="join-copy">
              <span className="eyebrow eyebrow--light">Join the platform</span>
              <h2>Turn your next dataset into a reproducible result.</h2>
              <p>
                Access is currently available to BRIN researchers, affiliated academic
                staff and approved graduate students.
              </p>
              <div className="join-note">
                <strong>Review schedule</strong>
                <span>Requests are reviewed by the IT administration team.</span>
              </div>
            </div>
            <div className="join-panel">
              <JoinForm />
            </div>
          </div>
        </section>
      </main>

      <footer className="site-footer">
        <div className="page-shell site-footer__inner">
          <div>
            <strong>BRIN</strong>
            <span>Neutron CT Platform</span>
          </div>
          <p>© 2026 Badan Riset dan Inovasi Nasional.</p>
          <nav aria-label="Footer">
            <a href="#about">About</a>
            <a href="#research">Research</a>
            <Link href="/login">Support</Link>
          </nav>
        </div>
      </footer>
    </>
  );
}
