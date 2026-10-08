"use client";

import type { ReactNode } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import gsap from "gsap";
import { useGSAP } from "@gsap/react";
import { Brand } from "@/components/brand";
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
  ["/admin/activity", "activity", "Activity logs"],
];

const userNavigation: readonly NavigationItem[] = [
  ["/dashboard", "dashboard", "Dashboard"],
  ["/workspace/predictions", "prediction", "Predictions"],
  ["/workspace/models", "model", "Available models"],
  ["/workspace/training", "training", "Model training"],
  ["/workspace/messages", "message", "Messages"],
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
  const navigation = user.role === "admin" ? adminNavigation : userNavigation;
  const currentLabel = navigation.find(([href]) => pathname === href || (href !== "/dashboard" && pathname.startsWith(`${href}/`)))?.[2] ?? "Workspace";

  useEffect(() => {
    document.body.classList.toggle("menu-open", open);
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => {
      document.body.classList.remove("menu-open");
      window.removeEventListener("keydown", closeOnEscape);
    };
  }, [open]);

  useGSAP(
    () => {
      if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
      gsap.fromTo(
        ".portal-content",
        { autoAlpha: 0, y: 16 },
        { autoAlpha: 1, y: 0, duration: 0.45, ease: "power3.out" },
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
    <div className="portal">
      <aside id="portal-navigation" className={`portal-sidebar${open ? " is-open" : ""}`}>
        <div className="portal-sidebar__brand">
          <Brand />
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
                key={href}
                className={active ? "is-active" : ""}
                onClick={() => setOpen(false)}
              >
                <span className="portal-nav__icon"><UiIcon name={icon} size={18} /></span>
                <span>{label}</span>
              </Link>
            );
          })}
        </nav>
        <div className="portal-user">
          <span className="portal-user__avatar" aria-hidden="true">{initials(user.name)}</span>
          <span className="portal-user__copy">
            <strong>{user.name}</strong>
            <span>{user.email}</span>
          </span>
          <button className="logout-button" type="button" title="Logout" onClick={logout}>
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
            <span><i aria-hidden="true" /> Secure session</span>
            <strong>{user.role === "admin" ? "Administrator" : "Researcher"}</strong>
          </div>
        </header>
        {children}
      </div>
    </div>
  );
}
