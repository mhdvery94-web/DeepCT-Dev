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

Do not point `staging` at the production database when testing admin mutations.
Set `LARAVEL_API_BASE_URL` independently in each Vercel environment.
