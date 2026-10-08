import { DataModule } from "@/components/data-module";

export function ModulePage({
  eyebrow,
  title,
  description,
}: {
  eyebrow: string;
  title: string;
  description: string;
}) {
  return (
    <main className="portal-content">
      <header className="portal-heading">
        <div>
          <span className="eyebrow">{eyebrow}</span>
          <h1>{title}</h1>
          <p>{description}</p>
        </div>
      </header>
      <DataModule title={title} />
    </main>
  );
}
