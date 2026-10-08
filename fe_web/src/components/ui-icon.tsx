export type IconName =
  | "activity"
  | "arrow"
  | "dashboard"
  | "database"
  | "logout"
  | "menu"
  | "message"
  | "model"
  | "news"
  | "prediction"
  | "request"
  | "refresh"
  | "shield"
  | "upload"
  | "users"
  | "workflow";

export function UiIcon({ name, size = 20 }: { name: IconName; size?: number }) {
  const common = {
    width: size,
    height: size,
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: 1.8,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
    "aria-hidden": true,
  };

  switch (name) {
    case "upload":
      return <svg {...common}><path d="M12 16V3m-5 5 5-5 5 5M4 15v5h16v-5" /></svg>;
    case "refresh":
      return <svg {...common}><path d="M20 7v5h-5M4 17v-5h5" /><path d="M6 7a7 7 0 0 1 11-2l3 3M4 16l3 3a7 7 0 0 0 11-2" /></svg>;
    case "dashboard":
      return <svg {...common}><rect x="3" y="3" width="7" height="7" /><rect x="14" y="3" width="7" height="4" /><rect x="14" y="11" width="7" height="10" /><rect x="3" y="14" width="7" height="7" /></svg>;
    case "users":
      return <svg {...common}><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" /></svg>;
    case "request":
      return <svg {...common}><circle cx="12" cy="8" r="4" /><path d="M4 21a8 8 0 0 1 13.1-6.2" /><path d="m17 19 2 2 4-5" /></svg>;
    case "message":
      return <svg {...common}><path d="M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4Z" /><path d="M8 9h8M8 13h5" /></svg>;
    case "news":
      return <svg {...common}><path d="M4 4h16v16H4z" /><path d="M8 8h8M8 12h8M8 16h5" /></svg>;
    case "model":
      return <svg {...common}><rect x="5" y="5" width="14" height="14" rx="1" /><path d="M9 1v4M15 1v4M9 19v4M15 19v4M1 9h4M19 9h4M1 15h4M19 15h4" /><circle cx="12" cy="12" r="3" /></svg>;
    case "activity":
      return <svg {...common}><path d="M3 12h4l2-7 4 14 2-7h6" /></svg>;
    case "prediction":
      return <svg {...common}><path d="M4 19V5M4 19h16" /><path d="m7 15 4-5 3 2 5-7" /><circle cx="19" cy="5" r="1.5" /></svg>;
    case "database":
      return <svg {...common}><ellipse cx="12" cy="5" rx="8" ry="3" /><path d="M4 5v6c0 1.7 3.6 3 8 3s8-1.3 8-3V5M4 11v6c0 1.7 3.6 3 8 3s8-1.3 8-3v-6" /></svg>;
    case "shield":
      return <svg {...common}><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z" /><path d="m9 12 2 2 4-5" /></svg>;
    case "workflow":
      return <svg {...common}><rect x="3" y="4" width="6" height="5" /><rect x="15" y="15" width="6" height="5" /><path d="M9 6.5h5a4 4 0 0 1 4 4V15M15 17.5h-5a4 4 0 0 1-4-4V9" /></svg>;
    case "menu":
      return <svg {...common}><path d="M4 7h16M4 12h16M4 17h16" /></svg>;
    case "logout":
      return <svg {...common}><path d="M10 17l5-5-5-5M15 12H3M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4" /></svg>;
    case "arrow":
      return <svg {...common}><path d="M5 12h14M13 6l6 6-6 6" /></svg>;
  }
}
