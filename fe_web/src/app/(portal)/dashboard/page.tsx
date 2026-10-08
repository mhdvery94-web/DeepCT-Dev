import type { CSSProperties } from "react";
import Link from "next/link";
import { RefreshButton } from "@/components/refresh-button";
import { UiIcon, type IconName } from "@/components/ui-icon";
import { getUserStats, requireUser } from "@/lib/api";

type Module = readonly [string, IconName, string, string];

const adminModules: readonly Module[] = [
  ["/admin/users", "users", "User management", "Manage accounts and researcher access."],
  ["/admin/access-requests", "request", "Access requests", "Review requests to join the platform."],
  ["/admin/news", "news", "Research news", "Manage publications and research updates."],
  ["/admin/storage", "database", "Disk management", "Monitor disk capacity and free unused application files."],
];
const userModules: readonly Module[] = [
  ["/workspace/predictions", "prediction", "Predictions", "Explore your CT prediction workspace."],
  ["/workspace/models", "model", "Available models", "Browse the models for your research."],
  ["/workspace/messages", "message", "Messages", "Stay in touch with the research team."],
];
const workflow: readonly [IconName, string, string][] = [
  ["upload", "Prepare your data", "Keep your CT input frames and metadata together."],
  ["model", "Choose a model", "Use a model suited to your research task."],
  ["prediction", "Run an analysis", "Submit a job through the prediction workspace."],
  ["activity", "Review the result", "Track activity and inspect the output."],
];

export default async function DashboardPage() {
  const user = await requireUser();
  const stats = await getUserStats(user.role);
  const modules = user.role === "admin" ? adminModules : userModules;
  const statuses = Object.entries(stats?.analyses_by_status ?? {});
  const largestCount = Math.max(1, ...statuses.map(([, count]) => count));
  const onlinePercent = stats && stats.models_total > 0
    ? Math.round((stats.models_online / stats.models_total) * 100)
    : 0;
  const cards: readonly [IconName, string, number | undefined, string][] = [
    ["activity", "Total activities", stats?.activities_total, "red"],
    ["dashboard", "Activities today", stats?.activities_today, "navy"],
    ["prediction", user.role === "admin" ? "Platform analyses" : "Your analyses", stats?.analyses_total, "rose"],
    ["model", "Models online", stats?.models_online, "wine"],
  ];

  return (
    <main className="portal-content dashboard-page">
      <header className="portal-heading dashboard-heading">
        <div>
          <span className="eyebrow">BRIN · Research workspace</span>
          <h1>Hello, {user.name.split(" ")[0]}.</h1>
          <p>{user.role === "admin" ? "Manage the platform and keep research moving." : "Your data, models, and research activity in one place."}</p>
        </div>
        <RefreshButton />
      </header>

      {!stats && <p className="dashboard-notice" role="status">Statistics are temporarily unavailable. Refresh to try again.</p>}

      <section className="dashboard-board" aria-label="Workspace overview">
        <article className="dashboard-tasks">
          <header className="dashboard-panel-heading">
            <span className="dashboard-panel-icon"><UiIcon name="request" size={21} /></span>
            <div><span className="dashboard-kicker">Get started</span><h2>Quick actions</h2></div>
          </header>
          <nav aria-label="Quick actions">
            {modules.slice(0, 3).map(([href, icon, title], index) => (
              <Link key={href} href={href}>
                <span className="dashboard-task-number">0{index + 1}</span>
                <span>{title}</span>
                <UiIcon name={icon} size={17} />
              </Link>
            ))}
          </nav>
          <Link className="dashboard-panel-link" href={user.role === "admin" ? "/admin/activity" : "/workspace/activity"}>View activity <UiIcon name="arrow" size={15} /></Link>
        </article>

        <article className="dashboard-analyses">
          <header className="dashboard-panel-heading">
            <div><span className="dashboard-kicker">Analysis overview</span><h2>Jobs by status</h2></div>
            <span className="dashboard-total"><strong>{stats?.analyses_total.toLocaleString() ?? "—"}</strong><small>Total</small></span>
          </header>
          {statuses.length > 0 && statuses.some(([, count]) => count > 0) ? (
            <div className="dashboard-chart" role="list" aria-label="Analysis counts by status">
              {statuses.map(([status, count]) => (
                <div className="dashboard-chart__column" key={status} role="listitem" aria-label={status + ": " + count}>
                  <strong>{count.toLocaleString()}</strong>
                  <div className="dashboard-chart__track"><span style={{ height: `${count / largestCount * 100}%` }} /></div>
                  <small>{status.replaceAll("_", " ")}</small>
                </div>
              ))}
            </div>
          ) : (
            <div className="dashboard-chart-empty">
              <UiIcon name="prediction" size={30} />
              <p>{stats ? "No analyses recorded yet." : "Waiting for statistics."}</p>
              <small>{stats ? "Your analysis statuses will appear here." : "Your data will appear when the API is available."}</small>
            </div>
          )}
          <p className="dashboard-panel-note">{user.role === "admin" ? "All platform analyses" : "Your recorded analyses"} · live API summary</p>
        </article>

        <article className="dashboard-models">
          <header className="dashboard-panel-heading">
            <div><span className="dashboard-kicker">Model availability</span><h2>Ready for research</h2></div>
            <UiIcon name="model" size={23} />
          </header>
          <div className="dashboard-model-ring" style={{ "--model-angle": `${Math.min(100, onlinePercent) * 3.6}deg` } as CSSProperties} aria-label={stats ? stats.models_online + " of " + stats.models_total + " models online" : "Model statistics unavailable"}>
            <div><strong>{stats ? onlinePercent + "%" : "—"}</strong><small>Online</small></div>
          </div>
          <p><strong>{stats?.models_online ?? "—"}</strong> online <span>/ {stats?.models_total ?? "—"} registered</span></p>
          <Link className="dashboard-panel-link" href={user.role === "admin" ? "/admin/models" : "/workspace/models"}>Explore models <UiIcon name="arrow" size={15} /></Link>
        </article>
      </section>

      <section className="dashboard-stats" aria-label="Research statistics">
        {cards.map(([icon, label, value, tone]) => (
          <article className={`dashboard-stat dashboard-stat--${tone}`} key={label}>
            <UiIcon name={icon} size={30} />
            <div><strong>{value?.toLocaleString() ?? "—"}</strong><span>{label}</span></div>
          </article>
        ))}
      </section>

      {user.role === "admin" && <div className="dashboard-admin-summary"><Link href="/admin/users">{stats?.users_total ?? "—"} accounts</Link><Link href="/admin/access-requests">{stats?.pending_requests ?? "—"} pending access requests</Link><Link href="/admin/storage">{stats?.free_bytes == null ? "—" : (stats.free_bytes / 1024 ** 3).toFixed(1) + " GB"} free disk space</Link></div>}
      <div className="dashboard-lower">
        <section className="dashboard-modules">
          <header className="dashboard-section-heading"><div><span className="dashboard-kicker">Everything in reach</span><h2>{user.role === "admin" ? "Administration" : "Research modules"}</h2></div><UiIcon name="dashboard" size={22} /></header>
          <div className="dashboard-module-list">
            {modules.map(([href, icon, title, description]) => (
              <Link href={href} key={href}>
                <span className="dashboard-module-icon"><UiIcon name={icon} size={21} /></span>
                <span><strong>{title}</strong><small>{description}</small></span>
                <UiIcon name="arrow" size={17} />
              </Link>
            ))}
          </div>
        </section>
        <section className="dashboard-workflow">
          <header className="dashboard-section-heading"><div><span className="dashboard-kicker">From input to insight</span><h2>Your research workflow</h2></div><UiIcon name="prediction" size={22} /></header>
          <ol>
            {workflow.map(([icon, title, description]) => (
              <li key={title}>
                <span><UiIcon name={icon} size={18} /></span>
                <div><h3>{title}</h3><p>{description}</p></div>
              </li>
            ))}
          </ol>
        </section>
      </div>
    </main>
  );
}
