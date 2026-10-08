# DeepCT Web

Next.js frontend for the BRIN Neutron CT Platform. Laravel in `../be` remains
the source of truth for users, roles, predictions, models, news, messages, and
all authorization decisions. Flutter in `../fe` remains the mobile client.

## Local development

Requirements: Node.js 22 and npm 10 (the versions used by the project laptop).

```bash
cp .env.example .env.local
npm ci
npm run dev
```

`LARAVEL_API_BASE_URL` is server-only and must include Laravel's `/api` suffix,
for example `http://127.0.0.1:8000/api`. The browser talks to same-origin Next
Route Handlers, so the Sanctum bearer token is kept in an `HttpOnly` cookie and
is never placed in browser storage.

## Checks

```bash
npm run check
npm run build
npm audit --omit=dev
```

## UI and motion

The landing page and portal share the BRIN red/navy visual system. Motion uses
`gsap` with `@gsap/react`: animations are scoped to their owning component,
cleaned up on unmount or route change, and disabled when the visitor requests
reduced motion. Keep API calls and authorization in Server Components or Route
Handlers; client-side motion wrappers receive already-rendered content.

The landing adapts the supplied **Bootslander** template by BootstrapMade:
two-column hero, layered waves, about/icon boxes and section titles, keeping
Home, About, Research, Join and Login. Template-only pricing, team, gallery and
testimonial sections are omitted. BRIN artwork comes from the repository's
`Images` folder; the hero uses an illustrative SVG CT reconstruction rather
than unrelated template photography.

The supplied flat-dashboard archive contains AI/EPS/JPG artwork, not HTML.
Its icon rail, three-panel overview, four statistic tiles and lower module
panels are implemented as responsive React components. The chart shows actual
analysis-status counts from Laravel, not a fabricated time series. Calendar
and download widgets without corresponding application data are omitted.
Module routes keep their existing functionality; this UI refresh does not add
missing CRUD or prediction implementations.

Keep BootstrapMade's attribution in the landing footer and Freepik's in the
portal footer as required by the supplied template licenses. Both include the
requested creator credit, `fajriansyah #bocahunpam`. No template vendor scripts
or extra Bootstrap/AOS bundles are loaded.

## Authentication boundary

- `src/proxy.ts` performs only an optimistic cookie-presence redirect.
- Server pages revalidate the session through Laravel `GET /user`.
- Laravel remains responsible for admin/user authorization on every protected
  endpoint.
- `src/app/api/backend/[...path]/route.ts` forwards an allowlisted set of HTTP
  headers and adds the server-held Sanctum token.

The BFF works well for normal JSON calls, chunked uploads, images, and videos.
Very large prediction-result downloads should eventually use short-lived,
signed Laravel URLs rather than passing multi-gigabyte files through a Vercel
function.

## Deployment model

Create a dedicated Vercel project with Root Directory `fe_web`. It may use the
same Vercel account/team as Flutter, but it must have a different project ID.

Branch promotion:

1. `develop` — integration and preview builds.
2. `staging` — acceptance testing against a staging Laravel/API instance.
3. `main` — production.

Set `LARAVEL_API_BASE_URL` independently in each Vercel environment whenever a
separate staging backend is available. Until then, the workflow intentionally
falls back from `STAGING_API_BASE_URL` to the Raspberry Pi production API, so
admin mutations performed from staging affect the same production database.
