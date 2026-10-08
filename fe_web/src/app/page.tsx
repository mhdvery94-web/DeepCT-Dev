import Link from "next/link";
import { CreatorCredit } from "@/components/creator-credit";
import { CtIllustration } from "@/components/ct-illustration";
import { JoinForm } from "@/components/join-form";
import { LandingExperience } from "@/components/landing-experience";
import { NewsShowcase } from "@/components/news-showcase";
import { SiteHeader } from "@/components/site-header";
import { Brand } from "@/components/brand";
import { UiIcon, type IconName } from "@/components/ui-icon";
import { getPublishedNews } from "@/lib/api";
import "./bootslander.css";

const capabilities: Array<{ icon: IconName; title: string; description: string }> = [
  { icon: "prediction", title: "CT frame prediction", description: "Generate missing frames and keep the origin of every result visible." },
  { icon: "model", title: "Model comparison", description: "Compare prediction models using the same scanned frames and retain the evidence." },
  { icon: "shield", title: "Governed access", description: "Researcher and administrator tools, with access managed by your institution." },
  { icon: "activity", title: "Traceable research", description: "Review your activity, compare outputs and preserve the evidence behind a run." },
];

export default async function Home() {
  const posts = await getPublishedNews();
  return (
    <LandingExperience>
      <SiteHeader />
      <main>
        <section className="bl-hero" id="home" aria-labelledby="hero-title">
          <div className="bl-container bl-hero__inner">
            <div className="bl-hero__copy">
              <span className="bl-hero__eyebrow" data-hero-reveal>BRIN · Neutron CT Platform</span>
              <h1 id="hero-title" data-hero-reveal>From CT data to the <span>next discovery.</span></h1>
              <p data-hero-reveal>A shared workspace for deep learning, neutron imaging and reproducible research. Built for the people behind the science.</p>
              <div className="bl-hero__actions" data-hero-reveal>
                <a className="bl-button bl-button--white" href="#research">Explore research <UiIcon name="arrow" size={17} /></a>
                <Link className="bl-workspace-link" href="/login"><span><UiIcon name="arrow" size={18} /></span> Open workspace</Link>
              </div>
              <div className="bl-hero__tags" data-hero-reveal><span>Neutron & X-ray CT</span><i aria-hidden="true" /><span>Deep learning</span></div>
            </div>
            <div className="bl-hero__art" data-hero-card><CtIllustration /></div>
          </div>
          {/* Wave geometry adapted from the supplied Bootslander template. */}
          <svg className="bl-waves" xmlns="http://www.w3.org/2000/svg" viewBox="0 24 150 28" preserveAspectRatio="none" aria-hidden="true">
            <defs><path id="brin-wave" d="M-160 44c30 0 58-18 88-18s58 18 88 18 58-18 88-18 58 18 88 18v44h-352z" /></defs>
            <g className="bl-wave bl-wave--back"><use href="#brin-wave" x="50" y="3" /></g>
            <g className="bl-wave bl-wave--middle"><use href="#brin-wave" x="50" y="0" /></g>
            <g className="bl-wave bl-wave--front"><use href="#brin-wave" x="50" y="9" /></g>
          </svg>
        </section>
        <section className="bl-section bl-about" id="about" aria-labelledby="about-title">
          <div className="bl-container bl-about__layout">
            <div className="bl-about__copy" data-reveal>
              <span className="bl-label">About the platform</span>
              <h2 id="about-title">Less friction.<br />More room for research.</h2>
              <p>DeepCT brings CT prediction, model comparison and research collaboration into one workspace for BRIN researchers and approved academic partners.</p>
              <p>Move from a dataset to a reviewable result, with the tools and records you need at every step.</p>
              <a className="bl-button" href="#join">Join the platform <UiIcon name="arrow" size={17} /></a>
            </div>
            <div className="bl-icon-boxes">
              {capabilities.map(({ icon, title, description }) => (
                <article className="bl-icon-box" key={title} data-reveal>
                  <span className="bl-icon-box__icon"><UiIcon name={icon} size={26} /></span>
                  <h3>{title}</h3><p>{description}</p>
                </article>
              ))}
            </div>
          </div>
          <div className="bl-container bl-feature-strip" aria-label="Research workflow" data-reveal>
            {([["database", "Upload your dataset"], ["model", "Select a model"], ["workflow", "Follow the queue"], ["shield", "Review the result"]] as const).map(([icon, label], index) => (
              <div key={label}><UiIcon name={icon} size={21} /><span>{label}</span><small>{String(index + 1).padStart(2, "0")}</small></div>
            ))}
          </div>
        </section>
        <section className="bl-section bl-research" id="research" aria-labelledby="research-title">
          <div className="bl-container">
            <header className="bl-section-title" data-reveal>
              <span>Research news</span><h2 id="research-title">Inside the research</h2>
              <p>Discover the latest projects, ideas and updates from our research community.</p>
            </header>
            <div data-reveal><NewsShowcase posts={posts} /></div>
          </div>
        </section>
        <section className="bl-section bl-join" id="join" aria-labelledby="join-title">
          <div className="bl-container">
            <header className="bl-section-title" data-reveal><span>Join the platform</span><h2 id="join-title">Your next research starts here</h2></header>
            <div className="bl-join__layout">
              <div className="bl-join__copy" data-reveal>
                <h3>A workspace for your next question.</h3>
                <p>Access is available to BRIN researchers, affiliated academic staff and approved graduate students. Tell us about your work and our administration team will review your request.</p>
                <div className="bl-contact-item"><span><UiIcon name="users" size={24} /></span><div><h4>Research community</h4><p>BRIN and approved academic partners</p></div></div>
                <div className="bl-contact-item"><span><UiIcon name="shield" size={24} /></span><div><h4>Reviewed access</h4><p>Accounts are issued by the administration team</p></div></div>
                <div className="bl-join__login"><p>Already have an account?</p><Link href="/login">Sign in to your workspace <UiIcon name="arrow" size={16} /></Link></div>
              </div>
              <div className="bl-join__form" data-reveal><h3>Request research access</h3><p>Complete the form below to get started.</p><JoinForm /></div>
            </div>
          </div>
        </section>
      </main>
      <footer className="bl-footer">
        <div className="bl-container bl-footer__main"><div><Brand /><p>A shared space for neutron CT research,<br />deep learning and scientific collaboration.</p></div></div>
        <div className="bl-container bl-footer__bottom"><p>© {new Date().getFullYear()} BRIN · Neutron CT Platform</p><CreatorCredit /></div>
      </footer>
    </LandingExperience>
  );
}
