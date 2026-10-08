"use client";

import { useRef, type ReactNode } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { useGSAP } from "@gsap/react";

gsap.registerPlugin(useGSAP, ScrollTrigger);

export function LandingExperience({ children }: { children: ReactNode }) {
  const scope = useRef<HTMLDivElement>(null);
  useGSAP(() => {
    const media = gsap.matchMedia();
    media.add("(prefers-reduced-motion: no-preference)", () => {
      gsap.timeline({ defaults: { duration: .65, ease: "power2.out" } })
        .from("[data-hero-reveal]", { opacity: 0, y: 18, stagger: .07 })
        .from("[data-hero-card]", { opacity: 0, y: 20 }, "<.12");
      gsap.utils.toArray<HTMLElement>("[data-reveal]").forEach((element) => {
        gsap.from(element, { y: 20, opacity: .15, duration: .6, ease: "power2.out", scrollTrigger: { trigger: element, start: "top 95%", once: true } });
      });
      const motion = gsap.timeline({ repeat: -1, yoyo: true })
        .to("[data-art-float]", { y: (i) => i === 0 ? -7 : 8, duration: 3, ease: "sine.inOut", stagger: .2 }, 0)
        .to("[data-ct-slice]", { x: (i) => i % 2 === 0 ? 3 : -3, duration: 3, ease: "sine.inOut", stagger: .12 }, 0)
        .to("[data-ct-core]", { opacity: .45, duration: 1.5, ease: "sine.inOut" }, 0)
        .to("[data-ct-sweep]", { y: 75, opacity: .4, duration: 3, ease: "sine.inOut" }, 0);
      // Pause continuous artwork motion outside the viewport.
      ScrollTrigger.create({ trigger: ".bl-hero__art", start: "top bottom", end: "bottom top", onToggle: (self) => self.isActive ? motion.resume() : motion.pause() });
    });
    return () => media.revert();
  }, { scope });
  return <div ref={scope} className="bootslander-page">{children}</div>;
}
