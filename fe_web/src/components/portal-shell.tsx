"use client";

import type { ReactNode } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import gsap from "gsap";
import { useGSAP } from "@gsap/react";
import { Brand } from "@/components/brand";
import { CreatorCredit } from "@/components/creator-credit";
import { UiIcon, type IconName } from "@/components/ui-icon";
import type { DeepCtUser } from "@/lib/types";

gsap.registerPlugin(useGSAP);

type NavigationItem = readonly [string, IconName, string];

const adminNavigation: readonly NavigationItem[] = [
  ["/dashboard", "dashboard", "Dashboard"],
  ["/admin/users", "users", "User management"],
  ["/admin/access-requests", "request", "Access requests"],
  ["/admin/messages", "message", "Messages"],
  ["/admin/news", "news", "Research news"],
  ["/admin/models", "model", "Model management"],
  ["/admin/storage", "database", "Disk management"],
  ["/admin/queue", "workflow", "Queue monitor"],
  ["/workspace/notifications", "news", "Notifications"],
  ["/workspace/profile", "shield", "Account settings"],
  ["/admin/activity", "activity", "Activity logs"],
];

const userNavigation: readonly NavigationItem[] = [
  ["/dashboard", "dashboard", "Dashboard"],
  ["/workspace/predictions", "prediction", "Predictions"],
  ["/workspace/models", "model", "Available models"],
  ["/workspace/messages", "message", "Messages"],
  ["/workspace/notifications", "news", "Notifications"],
  ["/workspace/profile", "shield", "Account settings"],
  ["/workspace/activity", "activity", "My activity"],
];

function initials(name: string): string {
  return name
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase();
}

export function PortalShell({ user, children }: { user: DeepCtUser; children: ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const main = useRef<HTMLDivElement>(null);
  const toggle = useRef<HTMLButtonElement>(null);
  const navigation = user.role === "admin" ? adminNavigation : userNavigation;
  const currentLabel = navigation.find(([href]) => pathname === href || (href !== "/dashboard" && pathname.startsWith(`${href}/`)))?.[2] ?? "Workspace";
  const avatar = user.avatar_url
    // Authenticated media must receive the browser's same-origin session cookie.
    // eslint-disable-next-line @next/next/no-img-element
    ? <img src={`/api/backend/users/${user.id}/avatar`} alt="" />
    : initials(user.name);

  useEffect(() => {
    document.body.classList.toggle("menu-open", open);
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape" && open) { setOpen(false); toggle.current?.focus(); }
    };
    const resize = () => { if (window.innerWidth > 800) setOpen(false); };
    window.addEventListener("keydown", closeOnEscape);
    window.addEventListener("resize", resize);
    return () => {
      document.body.classList.remove("menu-open");
      window.removeEventListener("keydown", closeOnEscape);
      window.removeEventListener("resize", resize);
    };
  }, [open]);

  useGSAP(
    () => {
      if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
      gsap.fromTo(
        ".portal-content",
        { autoAlpha: 0, y: 16 },
        { autoAlpha: 1, y: 0, duration: 0.45, ease: "power3.out", clearProps: "transform,opacity,visibility" },
      );
    },
    { scope: main, dependencies: [pathname], revertOnUpdate: true },
  );

  async function logout() {
    await fetch("/api/auth/logout", { method: "POST" }).catch(() => null);
    router.replace("/login");
    router.refresh();
  }

  return (
    <div className="portal flat-portal">
      <aside id="portal-navigation" className={`portal-sidebar${open ? " is-open" : ""}`}>
        <div className="portal-sidebar__brand">
          <Brand compact />
        </div>
        <span className="portal-sidebar__label">
          {user.role === "admin" ? "Administration" : "Research workspace"}
        </span>
        <nav className="portal-nav" aria-label="Portal navigation">
          {navigation.map(([href, icon, label]) => {
            const active = pathname === href || (href !== "/dashboard" && pathname.startsWith(`${href}/`));
            return (
              <Link
                href={href}
                prefetch={false}
                key={href}
                className={active ? "is-active" : ""}
                aria-current={active ? "page" : undefined}
                title={label}
                onClick={() => setOpen(false)}
              >
                <span className="portal-nav__icon"><UiIcon name={icon} size={18} /></span>
                <span className="portal-nav__label">{label}</span>
              </Link>
            );
          })}
        </nav>
        <div className="portal-user">
          <span className="portal-user__avatar" aria-hidden="true">{avatar}</span>
          <span className="portal-user__copy">
            <strong>{user.name}</strong>
            <span>{user.email}</span>
          </span>
          <button className="logout-button" type="button" title="Logout" aria-label="Logout" onClick={logout}>
            <UiIcon name="logout" size={17} />
          </button>
        </div>
      </aside>
      <button
        className={`portal-backdrop${open ? " is-open" : ""}`}
        type="button"
        tabIndex={open ? 0 : -1}
        aria-label="Close navigation"
        onClick={() => setOpen(false)}
      />
      <div className="portal-main" ref={main}>
        <header className="portal-topbar">
          <div className="portal-topbar__title">
            <button
              className="portal-menu-button"
              ref={toggle}
              type="button"
              aria-label="Toggle navigation"
              aria-controls="portal-navigation"
              aria-expanded={open}
              onClick={() => setOpen((value) => !value)}
            >
              <UiIcon name="menu" size={20} />
            </button>
            <span><small>Workspace</small><strong>{currentLabel}</strong></span>
          </div>
          <div className="portal-topbar__status">
            <span className="portal-account__avatar" aria-hidden="true">{avatar}</span>
            <span className="portal-account__copy"><strong>{user.name}</strong><small>{user.role === "admin" ? "Administrator" : "Researcher"}</small></span>
            <Link className="portal-account__security" href="/change-password" aria-label="Change password" title="Change password"><UiIcon name="shield" size={19} /></Link>
          </div>
        </header>
        {children}
        <footer className="portal-footer"><CreatorCredit /><span className="template-credit"><a href="https://www.freepik.com" target="_blank" rel="noreferrer">Designed by Freepik</a></span></footer>
      </div>
    </div>
  );
}
