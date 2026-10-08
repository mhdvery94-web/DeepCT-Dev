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
          yPercent: 600,
          duration: 2.8,
          ease: "none",
          repeat: -1,
          yoyo: true,
        });

        gsap.to("[data-scan-volume]", {
          rotation: "+=360",
          duration: 24,
          ease: "none",
          repeat: -1,
        });

        gsap.to("[data-scan-slice]", {
          rotation: (index) => `+=${index % 2 === 0 ? 34 : -28}`,
          scale: (index) => 1 + index * 0.012,
          duration: 3.4,
          ease: "sine.inOut",
          stagger: 0.12,
          repeat: -1,
          yoyo: true,
        });

        gsap.to("[data-scan-core]", {
          scale: 1.12,
          filter: "brightness(1.28)",
          duration: 1.35,
          ease: "sine.inOut",
          repeat: -1,
          yoyo: true,
        });

        gsap.to("[data-scan-orbit]", {
          rotation: (index) => (index === 0 ? "+=360" : "-=360"),
          duration: (index) => (index === 0 ? 18 : 13),
          ease: "none",
          repeat: -1,
        });

        gsap.to("[data-hero-float]", {
          y: (index) => (index === 0 ? -8 : 7),
          duration: (index) => (index === 0 ? 2.6 : 3.1),
          ease: "sine.inOut",
          stagger: 0.2,
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
