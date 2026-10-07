import Link from "next/link";
import { getUserStats, requireUser } from "@/lib/api";

const adminModules = [
  ["/admin/users", "01", "User management", "Manage accounts, roles and activation status."],
  ["/admin/access-requests", "02", "Access requests", "Review incoming researcher access requests."],
  ["/admin/news", "03", "Research news", "Publish responsive image and video research stories."],
  ["/admin/models", "04", "Model management", "Register, probe and maintain inference models."],
] as const;

const userModules = [
  ["/workspace/predictions", "01", "Predictions", "Upload CT datasets and follow the inference queue."],
  ["/workspace/models", "02", "Available models", "Inspect the models currently available for research."],
  ["/workspace/training", "03", "Model training", "Create and monitor your own training runs."],
  ["/workspace/messages", "04", "Messages", "Contact the administrator in one continuous thread."],
] as const;

export default async function DashboardPage() {
  const [user, stats] = await Promise.all([requireUser(), getUserStats()]);
  const modules = user.role === "admin" ? adminModules : userModules;

  return (
    <main className="portal-content">
      <header className="portal-heading">
        <div>
          <span className="eyebrow">Dashboard</span>
          <h1>Welcome, {user.name.split(" ")[0]}.</h1>
          <p>
            {user.role === "admin"
              ? "Monitor the platform and manage access from one administration workspace."
              : "Continue predictions, training and research collaboration from one workspace."}
          </p>
        </div>
      </header>

      <section className="stat-grid" aria-label="Account statistics">
        <article className="stat-card"><span>Total activities</span><strong>{stats?.activities_total ?? "—"}</strong></article>
        <article className="stat-card"><span>Activities today</span><strong>{stats?.activities_today ?? "—"}</strong></article>
        <article className="stat-card"><span>Total analyses</span><strong>{stats?.analyses_total ?? "—"}</strong></article>
        <article className="stat-card"><span>Models online</span><strong>{stats ? `${stats.models_online}/${stats.models_total}` : "—"}</strong></article>
      </section>

      <section className="module-grid" aria-label="Workspace modules">
        {modules.map(([href, number, title, description]) => (
          <article className="module-card" key={href}>
            <span>{number}</span>
            <h2>{title}</h2>
            <p>{description}</p>
            <Link href={href}>Open module →</Link>
          </article>
        ))}
      </section>
    </main>
  );
}
