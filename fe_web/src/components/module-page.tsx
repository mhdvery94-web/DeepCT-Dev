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
      <section className="section-placeholder">
        <span className="eyebrow">Next migration slice</span>
        <h2>Route and authorization are ready</h2>
        <p>
          The page is protected by the shared Laravel session. Its full data table and
          mutations will be migrated from Flutter in the next feature slice.
        </p>
      </section>
    </main>
  );
}
