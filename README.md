# QMS platform

A multi-tenant platform for running ISO 9001, ISO 14001 and ISO 45001 management systems.
A consulting firm uses it to manage its client organizations, and the clients use it themselves.
Data is organized as firm → organizations (clients) → records: documents, risks, nonconformities,
actions, audits, management reviews, training, suppliers, equipment and more. The model has
150 tables in 15 domains.

## Layout

| Path | What |
|---|---|
| `db/model.py` | **Single source of truth** for the data model (tables, enums, RLS classes). |
| `db/gen.py` | Generates `db/generated/schema.sql` (PostgreSQL 16 DDL + RLS) and `model.json` (metadata for the API and UI). |
| `db/migrations/` | Ordered SQL migrations. `0001_baseline.sql` is the generated schema; `0002_app_role.sql` sets up the runtime role. |
| `db/seed/dev.sql` | Demo firm, two clients, five users, sample registers. |
| `db/init/` | Cluster roles for local Postgres (mounted by docker compose). |
| `backend/` | FastAPI API (`qms_api`) + pytest suite against a real database. |
| `frontend/` | React + TypeScript app (Vite), generated from the same metadata. |

## Run it

```bash
docker compose up -d db          # or any local PostgreSQL 16 after running db/init/00_roles.sql
make migrate seed
make api                         # http://localhost:8000/docs
make web                         # http://localhost:5173
```

Sign in with one of the dev accounts listed on the login page:

| Account | Sees |
|---|---|
| `owner@atlas.test` | Firm owner: every client (Beta is read-only, by Beta's choice) |
| `consultant@atlas.test` | Consultant: only Alpha, the client they are assigned to |
| `qse@alpha.test`, `gerant@alpha.test` | Alpha's own users |
| `qse@beta.test` | Beta's own user |

Tests: `make test`. They create and drop a `qms_test` database, so `qms_owner` needs `CREATEDB`.

## How tenancy is enforced

Isolation lives in the database, not in API code:

* Every client table has `organization_id`. Foreign keys between client tables are composite
  `(organization_id, x_id)`, so a row can never reference another client's record.
* Every table has RLS policies built on `app.current_user_id()`. The API sets
  `app.user_id` with `set_config(..., true)` at the start of each request's transaction (`backend/qms_api/db.py`).
* The API connects as `qms_api`, a member of `qms_app`. That role owns nothing and has no
  `BYPASSRLS`, so the policies always apply. Only migrations and seeds run as the owner.
* The client controls the firm's access (`organizations.firm_access`: full / read_only / none).
  A trigger stops the firm from changing it.
* `backend/tests/test_tenancy.py` checks these guarantees end to end.

## API

* `POST /api/auth/dev-login` (only with `QMS_DEV_AUTH=true`) → bearer token. `GET /api/me`, `GET /api/meta`.
* `GET|POST /api/orgs/{org}/t/{table}` and `GET|PATCH|DELETE /api/orgs/{org}/t/{table}/{id}`
  for organization data.
* `/api/t/{table}[/{id}]` for the firm library, global reference and platform tables.
* Lists support `?col=v`, `col__ne|lt|lte|gt|gte=v`, `col__in=a,b`, `col__isnull=true`, `q=`
  (text search), `order=col|-col`, `limit`, `offset`.
* Link tables (composite key) are deleted with `DELETE …/t/{table}?key1=…&key2=…`.
* Writes are appended to `activity_log` with a before/after diff.

## Changing the model

1. Edit `db/model.py`, then run `make gen`.
2. **Before the first production deploy:** copy `db/generated/schema.sql` over
   `db/migrations/0001_baseline.sql`.
   **After it:** write a new numbered migration. The migrator refuses to run a migration that changed after it was applied.
3. `test_model_sync.py` fails if the generated files or the baseline drift from the model.

## Configuration (`QMS_*` env vars)

`DATABASE_URL`, `OWNER_DATABASE_URL`, `JWT_SECRET` (the API refuses to start with the default
secret unless `DEV_AUTH` is on), `JWT_TTL_MINUTES`, `DEV_AUTH`, `CORS_ORIGINS`.
