"use client";

import type { ReactNode } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useState } from "react";
import { Brand } from "@/components/brand";
import type { DeepCtUser } from "@/lib/types";

const adminNavigation = [
  ["/dashboard", "00", "Dashboard"],
  ["/admin/users", "01", "User management"],
  ["/admin/access-requests", "02", "Access requests"],
  ["/admin/messages", "03", "Messages"],
  ["/admin/news", "04", "Research news"],
  ["/admin/models", "05", "Model management"],
  ["/admin/activity", "06", "Activity logs"],
] as const;

const userNavigation = [
  ["/dashboard", "00", "Dashboard"],
  ["/workspace/predictions", "01", "Predictions"],
  ["/workspace/models", "02", "Available models"],
  ["/workspace/training", "03", "Model training"],
  ["/workspace/messages", "04", "Messages"],
  ["/workspace/activity", "05", "My activity"],
] as const;

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
  const navigation = user.role === "admin" ? adminNavigation : userNavigation;

  async function logout() {
    await fetch("/api/auth/logout", { method: "POST" }).catch(() => null);
    router.replace("/login");
    router.refresh();
  }

  return (
    <div className="portal">
      <aside className={`portal-sidebar${open ? " is-open" : ""}`}>
        <div className="portal-sidebar__brand">
          <Brand />
        </div>
        <span className="portal-sidebar__label">
          {user.role === "admin" ? "Administration" : "Research workspace"}
        </span>
        <nav className="portal-nav" aria-label="Portal navigation">
          {navigation.map(([href, number, label]) => {
            const active = pathname === href || (href !== "/dashboard" && pathname.startsWith(`${href}/`));
            return (
              <Link
                href={href}
                key={href}
                className={active ? "is-active" : ""}
                onClick={() => setOpen(false)}
              >
                <span>{number}</span>
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
            ↗
          </button>
        </div>
      </aside>
      <div className="portal-main">
        <header className="portal-topbar">
          <button
            className="portal-menu-button"
            type="button"
            aria-label="Toggle navigation"
            aria-expanded={open}
            onClick={() => setOpen((value) => !value)}
          >
            ☰
          </button>
          <strong>Neutron CT Platform</strong>
          <span>{user.role === "admin" ? "Administrator" : "Researcher"}</span>
        </header>
        {children}
      </div>
    </div>
  );
}
