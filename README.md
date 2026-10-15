# QMS platform

A multi-tenant platform for running ISO 9001, ISO 14001 and ISO 45001 management systems.
A consulting firm uses it to manage its client organizations, and the clients use it themselves.
Data is organized as firm → organizations (clients) → records: documents, risks, nonconformities,
actions, audits, management reviews, training, suppliers, equipment and more. The model has
150 tables in 15 domains.

**Stack:** Next.js 15 (App Router, TypeScript) for the web app and the API, and PostgreSQL 16.
It runs for free on Vercel (Hobby) with Neon Postgres (free tier).

## Deploy to Vercel + Neon (free)

1. Import this repository in Vercel (**Add New → Project**). Keep the defaults.
2. Under the project's **Storage** tab, add **Neon** (free plan). Vercel then sets
   `DATABASE_URL` and `DATABASE_URL_UNPOOLED` for you.
3. Add these environment variables (**Settings → Environment Variables**):

   | Variable | Value |
   |---|---|
   | `QMS_JWT_SECRET` | a random string, e.g. `openssl rand -base64 32` |
   | `QMS_MIGRATE_ON_BUILD` | `true`: each build applies pending migrations |
   | `QMS_SEED_DEMO` | `true`: loads the demo data into an empty database |
   | `QMS_DEV_AUTH` | `true`: password-less login with the demo accounts |

4. Redeploy. The `vercel-build` script migrates the database, seeds it, then builds the app.

> `QMS_DEV_AUTH=true` lets anyone with the URL sign in as a demo user. That is fine for a
> test deployment with demo data, but never for real client data. Real login is the next milestone.

Optionally, set the Vercel function region (**Settings → Functions**) to the Neon database's region for faster queries.

## Run locally

```bash
docker compose up -d db          # or any PostgreSQL 16 after running db/init/00_roles.sql
cp .env.example .env.local
npm install
npm run db:migrate && npm run db:seed
npm run dev                      # http://localhost:3000
```

Sign in with one of the demo accounts listed on the login page:

| Account | Sees |
|---|---|
| `owner@atlas.test` | Firm owner: every client (Beta is read-only, by Beta's choice) |
| `consultant@atlas.test` | Consultant: only Alpha, the client they are assigned to |
| `qse@alpha.test`, `gerant@alpha.test` | Alpha's own users |
| `qse@beta.test` | Beta's own user |

`npm test` runs the test suite against a throwaway `qms_test` database (the connecting role needs
`CREATEDB`; override the server with `QMS_TEST_ADMIN_URL`). `npm run typecheck` checks the types.

## Layout

| Path | What |
|---|---|
| `db/model.py` | **Single source of truth** for the data model (tables, enums, RLS classes). |
| `db/gen.py` | Generates `db/generated/schema.sql` (DDL + RLS) and `model.json` (metadata for the API and UI). Python, build-time only. |
| `db/migrations/` | Ordered SQL migrations. `0001_baseline.sql` is the generated schema; `0002_app_role.sql` sets up the runtime role. |
| `db/seed/dev.sql` | Demo firm, two clients, five users, sample registers. |
| `lib/server/` | API: `router.ts` (all routes), `crud.ts` (generic CRUD), `db.ts` (per-request transaction), `model.ts`, `auth.ts`, `migrate.ts`. |
| `app/api/[...path]/route.ts` | Mounts the API as a single serverless function. |
| `app/`, `components/`, `lib/client/` | The web app, generated from the same metadata. |
| `tests/` | Vitest suite. It calls the API in-process against a real database. |
| `scripts/` | `migrate`, `seed`, and `deploy-db` (run by `vercel-build`). |
| `edii/`, `lib/edii/`, `app/edii/` | Classification of *établissements dangereux, insalubres ou incommodes* (1ère, 2ème, 3ème catégorie, non classé): the official texts, the OCR pipeline that turns them into `edii/nomenclature.json`, the classifier and its page at `/edii`. See `edii/README.md`. |

## How tenancy is enforced

Isolation lives in the database, not in API code:

* Every client table has `organization_id`. Foreign keys between client tables are composite
  `(organization_id, x_id)`, so a row can never reference another client's record.
* Every table has RLS policies built on `app.current_user_id()`. Each request runs in one transaction that starts with
  `SET LOCAL ROLE qms_app` and `set_config('app.user_id', …, true)` (`lib/server/db.ts`). `qms_app` owns nothing
  and has no `BYPASSRLS`, so the policies apply even though the connection string is the owner's
  (as on Neon).
* The client controls the firm's access (`organizations.firm_access`: full / read_only / none).
  A trigger stops the firm from changing it.
* `tests/tenancy.test.ts` checks these guarantees end to end.

## API

* Session: `POST /api/auth/dev-login {email}` sets an httpOnly cookie and also returns a bearer token for scripts.
  `POST /api/auth/logout`, `GET /api/me`, `GET /api/meta`.
* `GET|POST /api/orgs/{org}/t/{table}` and `GET|PATCH|DELETE /api/orgs/{org}/t/{table}/{id}` for organization data.
* `/api/t/{table}[/{id}]` for the firm library, global reference and platform tables.
* Lists support `?col=v`, `col__ne|lt|lte|gt|gte=v`, `col__in=a,b`, `col__isnull=true`, `q=`
  (text search), `order=col|-col`, `limit` (≤ 500), `offset`.
* Link tables (composite key) are deleted with `DELETE …/t/{table}?key1=…&key2=…`.
* Writes must be `application/json`. Each write is appended to `activity_log` with a before/after diff.

## Changing the model

1. Edit `db/model.py`, then run `npm run db:gen` (needs Python 3).
2. **Before the first deployment that holds real data:** copy `db/generated/schema.sql` over
   `db/migrations/0001_baseline.sql`, and reset test databases.
   **After it:** write a new numbered migration. The migrator refuses to run a migration that changed after it was applied.
3. `tests/model-sync.test.ts` fails if the generated files or the baseline drift from the model.
