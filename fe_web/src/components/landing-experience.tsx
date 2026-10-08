"use client";

import type { ReactNode } from "react";
import { useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { useGSAP } from "@gsap/react";

gsap.registerPlugin(useGSAP, ScrollTrigger);

export function LandingExperience({ children }: { children: ReactNode }) {
  const scope = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      const media = gsap.matchMedia();

      media.add("(prefers-reduced-motion: no-preference)", () => {
        gsap
          .timeline({ defaults: { duration: 0.75, ease: "power3.out" } })
          .from("[data-hero-reveal]", { autoAlpha: 0, y: 28, stagger: 0.09 })
          .from("[data-hero-card]", { autoAlpha: 0, y: 34, scale: 0.975 }, "-=0.45");

        gsap.utils.toArray<HTMLElement>("[data-reveal]").forEach((element) => {
          gsap.from(element, {
            autoAlpha: 0,
            y: 34,
            duration: 0.7,
            ease: "power3.out",
            scrollTrigger: {
              trigger: element,
              start: "top 88%",
              toggleActions: "play none none none",
            },
          });
        });

        gsap.to("[data-scan-line]", {
          yPercent: 520,
          duration: 3.2,
          ease: "none",
          repeat: -1,
          yoyo: true,
        });
      });

      return () => media.revert();
    },
    { scope },
  );

  return <div ref={scope} className="landing-experience">{children}</div>;
}
