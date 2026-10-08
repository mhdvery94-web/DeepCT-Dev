"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { Brand } from "@/components/brand";

const navItems = [
  ["#home", "Home"],
  ["#about", "About"],
  ["#research", "Research"],
  ["#join", "Join"],
] as const;

export function SiteHeader() {
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState("#home");
  const toggle = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    document.body.classList.toggle("menu-open", open);
    const close = (event: KeyboardEvent) => {
      if (event.key === "Escape" && open) { setOpen(false); toggle.current?.focus(); }
    };
    const resize = () => { if (window.innerWidth > 900) setOpen(false); };
    window.addEventListener("keydown", close);
    window.addEventListener("resize", resize);
    return () => {
      document.body.classList.remove("menu-open");
      window.removeEventListener("keydown", close);
      window.removeEventListener("resize", resize);
    };
  }, [open]);

  useEffect(() => {
    const observer = new IntersectionObserver((entries) => {
      for (const entry of entries) if (entry.isIntersecting) setActive(`#${entry.target.id}`);
    }, { rootMargin: "-15% 0px -60% 0px" });
    navItems.forEach(([href]) => { const element = document.querySelector(href); if (element) observer.observe(element); });
    return () => observer.disconnect();
  }, []);

  return (
    <header className="site-header">
      <div className="site-header__inner bl-container">
        <Brand compact />
        <button
          className="menu-button"
          ref={toggle}
          type="button"
          aria-expanded={open}
          aria-controls="primary-navigation"
          onClick={() => setOpen((value) => !value)}
        >
          <span className="sr-only">Buka menu</span>
          <span />
          <span />
          <span />
        </button>
        <nav
          id="primary-navigation"
          className={`site-nav${open ? " site-nav--open" : ""}`}
          aria-label="Navigasi utama"
        >
          {navItems.map(([href, label]) => (
            <a key={href} href={href} className={active === href ? "is-active" : ""} aria-current={active === href ? "location" : undefined} onClick={() => { setActive(href); setOpen(false); }}>
              {label}
            </a>
          ))}
          <Link className="button button--primary site-nav__login" href="/login">
            Login
          </Link>
        </nav>
      </div>
    </header>
  );
}
