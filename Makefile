# Local development. Prerequisites: PostgreSQL 16 (or `docker compose up -d db`), uv, Node 22.
.PHONY: gen db-reset migrate seed api web test lint

gen:            ## regenerate db/generated from db/model.py
	cd db && python3 gen.py

db-reset:       ## drop and recreate the local database, migrate, seed
	psql "postgresql://qms_owner:qms@localhost:5432/postgres" -c "DROP DATABASE IF EXISTS qms WITH (FORCE)" -c "CREATE DATABASE qms"
	$(MAKE) migrate seed

migrate:
	cd backend && uv run python -m qms_api.migrate

seed:
	cd backend && uv run python -m qms_api.seed

api:            ## API on :8000 with password-less dev login
	cd backend && QMS_DEV_AUTH=true uv run uvicorn qms_api.main:app --reload --port 8000

web:            ## web app on :5173 (proxies /api to :8000)
	cd frontend && npm install && npm run dev

test:
	cd backend && uv run pytest -q

lint:
	cd backend && uv run ruff check .
	cd frontend && npm run typecheck
