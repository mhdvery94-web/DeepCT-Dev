import Image from "next/image";
import Link from "next/link";
import { JoinForm } from "@/components/join-form";
import { LandingExperience } from "@/components/landing-experience";
import { NewsShowcase } from "@/components/news-showcase";
import { SiteHeader } from "@/components/site-header";
import { UiIcon, type IconName } from "@/components/ui-icon";
import { getPublishedNews } from "@/lib/api";

const features: Array<{
  number: string;
  icon: IconName;
  title: string;
  description: string;
}> = [
  {
    number: "01",
    icon: "model",
    title: "High-fidelity analysis",
    description:
      "Validated neural architectures transform CT datasets into repeatable, reviewable research outputs.",
  },
  {
    number: "02",
    icon: "shield",
    title: "Sanctioned environment",
    description:
      "Data and model access stay inside institutionally governed infrastructure with a complete activity trail.",
  },
  {
    number: "03",
    icon: "workflow",
    title: "Streamlined workflow",
    description:
      "Upload, queue, monitor, compare and export results from one focused workspace across desktop and mobile.",
  },
];

export default async function Home() {
  const posts = await getPublishedNews();

  return (
    <LandingExperience>
      <SiteHeader />
      <main>
        <section className="hero" id="home">
          <div className="hero__glow" aria-hidden="true" />
          <div className="page-shell hero__inner">
            <div className="hero__copy">
              <span className="hero__kicker" data-hero-reveal>
                <span className="hero__status-dot" aria-hidden="true" />
                BRIN research infrastructure
              </span>
              <h1 data-hero-reveal>
                Intelligence for the next frame of <em>CT research.</em>
              </h1>
              <p data-hero-reveal>
                A secure workspace for neutron and X-ray CT prediction, model training,
                and reproducible scientific analysis.
              </p>
              <div className="hero__actions" data-hero-reveal>
                <a className="button button--primary" href="#research">
                  Explore research <UiIcon name="arrow" size={17} />
                </a>
                <Link className="text-link text-link--light" href="/login">
                  Open workspace <UiIcon name="arrow" size={15} />
                </Link>
              </div>
              <dl className="hero__metrics" data-hero-reveal>
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

            <div className="hero__visual" data-hero-card aria-label="Neutron CT analysis interface preview">
              <div className="hero-console">
                <div className="hero-console__topbar">
                  <span className="hero-console__dots" aria-hidden="true"><i /><i /><i /></span>
                  <span>CT / ANALYSIS WORKSPACE</span>
                  <span className="hero-console__live"><i /> SYSTEM READY</span>
                </div>
                <div className="hero-console__body">
                  <div className="hero-scan">
                    <div className="hero-scan__volume" aria-hidden="true">
                      <i /><i /><i /><i /><i />
                      <span />
                    </div>
                    <div className="hero-scan__grid" aria-hidden="true" />
                    <div className="hero-scan__line" data-scan-line aria-hidden="true" />
                    <span className="hero-scan__label">Reconstruction preview / axial</span>
                    <div className="hero-scan__focus" aria-hidden="true"><i /><i /><i /><i /></div>
                  </div>
                  <aside className="hero-console__rail">
                    <div className="console-panel console-panel--accent">
                      <span>Pipeline</span>
                      <strong>Frame interpolation</strong>
                      <small>Ready for validated datasets</small>
                    </div>
                    <div className="console-panel">
                      <span>Processing path</span>
                      <div className="console-steps" aria-label="Upload, analyze and review workflow">
                        <i className="is-complete">01</i><b />
                        <i className="is-complete">02</i><b />
                        <i>03</i>
                      </div>
                      <small>Upload · Analyze · Review</small>
                    </div>
                    <div className="console-panel console-panel--metric">
                      <UiIcon name="shield" size={19} />
                      <span><strong>Governed access</strong><small>Role-based workspace</small></span>
                    </div>
                  </aside>
                </div>
                <div className="hero-console__footer">
                  <span>NEUTRON / X-RAY</span>
                  <span>REPRODUCIBLE PIPELINE</span>
                  <span>BRIN · 2026</span>
                </div>
              </div>
              <div className="hero-float hero-float--model" aria-hidden="true">
                <span><UiIcon name="model" size={18} /> Model workspace</span>
                <strong>Validated architecture</strong>
              </div>
              <div className="hero-float hero-float--research" aria-hidden="true">
                <Image src="/assets/BRIN.png" alt="" width={30} height={30} />
                <span>National research<br />infrastructure</span>
              </div>
            </div>
          </div>
          <div className="hero__ticker" aria-hidden="true">
            <div className="page-shell">
              <span>NEUTRON CT</span><i />
              <span>DEEP LEARNING</span><i />
              <span>SCIENTIFIC GOVERNANCE</span><i />
              <span>REPRODUCIBLE RESULTS</span>
            </div>
          </div>
        </section>

        <section className="section section--capabilities" id="about">
          <div className="page-shell">
            <div className="section-heading section-heading--split" data-reveal>
              <div>
                <span className="eyebrow">Platform capabilities</span>
                <h2>One workflow. Every research checkpoint visible.</h2>
              </div>
              <p>
                Access state-of-the-art models vetted for institutional use while
                keeping every dataset, decision and result traceable.
              </p>
            </div>
            <div className="feature-grid" data-reveal>
              {features.map((feature) => (
                <article className="feature-card" key={feature.number}>
                  <div className="feature-card__top">
                    <span className="feature-card__icon"><UiIcon name={feature.icon} size={22} /></span>
                    <span className="feature-card__number">{feature.number}</span>
                  </div>
                  <h3>{feature.title}</h3>
                  <p>{feature.description}</p>
                  <span className="feature-card__line" aria-hidden="true" />
                </article>
              ))}
            </div>
          </div>
        </section>

        <section className="section section--research" id="research">
          <div className="page-shell">
            <div className="section-heading section-heading--split" data-reveal>
              <div>
                <span className="eyebrow">Latest research</span>
                <h2>Stories from the edge of imaging science.</h2>
              </div>
              <p>
                Image and video share one responsive stage, paired with concise context
                so every publication is easy to explore on any screen.
              </p>
            </div>
            <div data-reveal><NewsShowcase posts={posts} /></div>
          </div>
        </section>

        <section className="section section--dark" id="join">
          <div className="join-glow" aria-hidden="true" />
          <div className="page-shell join-layout">
            <div className="join-copy" data-reveal>
              <span className="eyebrow eyebrow--light">Join the platform</span>
              <h2>Turn your next dataset into a reproducible result.</h2>
              <p>
                Access is currently available to BRIN researchers, affiliated academic
                staff and approved graduate students.
              </p>
              <div className="join-note">
                <UiIcon name="shield" size={21} />
                <span><strong>Governed onboarding</strong><small>Requests are reviewed by the IT administration team.</small></span>
              </div>
            </div>
            <div className="join-panel" data-reveal>
              <div className="join-panel__heading">
                <span>Access request</span>
                <strong>Tell us about your research.</strong>
              </div>
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
            <a href="https://www.freepik.com" target="_blank" rel="noreferrer">Design references by Freepik</a>
          </nav>
        </div>
      </footer>
    </LandingExperience>
  );
}
