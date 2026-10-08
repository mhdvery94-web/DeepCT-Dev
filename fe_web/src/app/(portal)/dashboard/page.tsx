import type { CSSProperties } from "react";
import Link from "next/link";
import { UiIcon, type IconName } from "@/components/ui-icon";
import { getUserStats, requireUser } from "@/lib/api";

type ModuleDefinition = readonly [string, IconName, string, string];

const adminModules: readonly ModuleDefinition[] = [
  ["/admin/users", "users", "User management", "Manage accounts, roles and activation status."],
  ["/admin/access-requests", "request", "Access requests", "Review incoming researcher access requests."],
  ["/admin/news", "news", "Research news", "Publish responsive image and video research stories."],
  ["/admin/models", "model", "Model management", "Register, probe and maintain inference models."],
];

const userModules: readonly ModuleDefinition[] = [
  ["/workspace/predictions", "prediction", "Predictions", "Upload CT datasets and follow the inference queue."],
  ["/workspace/models", "model", "Available models", "Inspect the models currently available for research."],
  ["/workspace/training", "training", "Model training", "Create and monitor your own training runs."],
  ["/workspace/messages", "message", "Messages", "Contact the administrator in one continuous thread."],
];

function formatStatus(value: string): string {
  return value.replaceAll("_", " ").replace(/\b\w/g, (character) => character.toUpperCase());
}

export default async function DashboardPage() {
  const [user, stats] = await Promise.all([requireUser(), getUserStats()]);
  const modules = user.role === "admin" ? adminModules : userModules;
  const readiness = stats?.models_total
    ? Math.round((stats.models_online / stats.models_total) * 100)
    : 0;
  const analysisStatuses = Object.entries(stats?.analyses_by_status ?? {});
  const largestStatus = Math.max(1, ...analysisStatuses.map(([, count]) => count));

  const statCards: Array<{
    label: string;
    value: string | number;
    detail: string;
    icon: IconName;
    tone: string;
  }> = [
    {
      label: "Total activities",
      value: stats?.activities_total ?? "—",
      detail: "Recorded events",
      icon: "activity",
      tone: "coral",
    },
    {
      label: "Activities today",
      value: stats?.activities_today ?? "—",
      detail: "Current day",
      icon: "workflow",
      tone: "amber",
    },
    {
      label: "Total analyses",
      value: stats?.analyses_total ?? "—",
      detail: "Research runs",
      icon: "prediction",
      tone: "blue",
    },
    {
      label: "Models online",
      value: stats ? `${stats.models_online}/${stats.models_total}` : "—",
      detail: "Available now",
      icon: "model",
      tone: "teal",
    },
  ];

  return (
    <main className="portal-content dashboard-page">
      <header className="portal-heading">
        <div>
          <span className="eyebrow">Research command center</span>
          <h1>Welcome, {user.name.split(" ")[0]}.</h1>
          <p>
            {user.role === "admin"
              ? "Monitor the platform and manage access from one administration workspace."
              : "Continue predictions, training and research collaboration from one workspace."}
          </p>
        </div>
        <div className="dashboard-heading__badge">
          <span><i aria-hidden="true" /> Workspace active</span>
          <small>{user.role === "admin" ? "Administration scope" : "Researcher scope"}</small>
        </div>
      </header>

      <section className="stat-grid" aria-label="Account statistics">
        {statCards.map((card) => (
          <article className={`stat-card stat-card--${card.tone}`} key={card.label}>
            <span className="stat-card__icon"><UiIcon name={card.icon} size={20} /></span>
            <span className="stat-card__label">{card.label}</span>
            <strong>{card.value}</strong>
            <small>{card.detail}</small>
          </article>
        ))}
      </section>

      <section className="dashboard-overview" aria-label="Platform overview">
        <article className="workflow-panel">
          <header className="panel-heading">
            <div><span>Research workflow</span><h2>From dataset to validated result</h2></div>
            <span className="panel-heading__tag">Operational path</span>
          </header>
          <div className="workflow-map">
            <div><span><UiIcon name="database" size={20} /></span><strong>Upload</strong><small>Dataset intake</small></div>
            <i aria-hidden="true" />
            <div><span><UiIcon name="workflow" size={20} /></span><strong>Queue</strong><small>Managed process</small></div>
            <i aria-hidden="true" />
            <div><span><UiIcon name="model" size={20} /></span><strong>Analyze</strong><small>Selected model</small></div>
            <i aria-hidden="true" />
            <div><span><UiIcon name="shield" size={20} /></span><strong>Review</strong><small>Auditable result</small></div>
          </div>
          <div className="analysis-status">
            <span className="analysis-status__title">Analysis distribution</span>
            {analysisStatuses.length ? (
              <div className="analysis-status__list">
                {analysisStatuses.slice(0, 4).map(([status, count]) => (
                  <div key={status}>
                    <span>{formatStatus(status)}</span>
                    <i><b style={{ width: `${Math.max(5, (count / largestStatus) * 100)}%` }} /></i>
                    <strong>{count}</strong>
                  </div>
                ))}
              </div>
            ) : (
              <p>No analysis status has been recorded yet. New research runs will appear here.</p>
            )}
          </div>
        </article>

        <article className="readiness-panel">
          <header className="panel-heading">
            <div><span>System readiness</span><h2>Model availability</h2></div>
          </header>
          <div
            className="readiness-ring"
            style={{ "--readiness": `${readiness * 3.6}deg` } as CSSProperties}
            aria-label={`${readiness}% of models online`}
          >
            <span><strong>{readiness}%</strong><small>online</small></span>
          </div>
          <dl className="readiness-details">
            <div><dt>Online</dt><dd>{stats?.models_online ?? "—"}</dd></div>
            <div><dt>Registered</dt><dd>{stats?.models_total ?? "—"}</dd></div>
          </dl>
          <p>Availability is calculated from the models currently registered with the platform.</p>
        </article>
      </section>

      <section className="dashboard-modules" aria-labelledby="modules-title">
        <header className="dashboard-modules__heading">
          <div><span className="eyebrow">Workspace modules</span><h2 id="modules-title">Continue your work</h2></div>
          <span>{String(modules.length).padStart(2, "0")} available modules</span>
        </header>
        <div className="module-grid">
          {modules.map(([href, icon, title, description], index) => (
            <article className="module-card" key={href}>
              <div className="module-card__top">
                <span className="module-card__icon"><UiIcon name={icon} size={22} /></span>
                <span>{String(index + 1).padStart(2, "0")}</span>
              </div>
              <h2>{title}</h2>
              <p>{description}</p>
              <Link href={href}>Open module <UiIcon name="arrow" size={16} /></Link>
            </article>
          ))}
        </div>
      </section>
    </main>
  );
}
