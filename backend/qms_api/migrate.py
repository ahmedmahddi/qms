"""Apply db/migrations/*.sql in order, as the schema owner.

    python -m qms_api.migrate            apply pending migrations
    python -m qms_api.migrate --status   list applied / pending
"""

import argparse
import hashlib

import psycopg

from .config import get_settings


def migrate(owner_url: str | None = None, verbose: bool = True) -> list[str]:
    s = get_settings()
    files = sorted(s.migrations_dir.glob("*.sql"))
    applied_now = []
    with psycopg.connect(owner_url or s.owner_database_url, autocommit=True) as conn:
        conn.execute("CREATE TABLE IF NOT EXISTS schema_migrations ("
                     "name text PRIMARY KEY, sha256 text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())")
        applied = {r[0]: r[1] for r in conn.execute("SELECT name, sha256 FROM schema_migrations")}
        for f in files:
            body = f.read_text(encoding="utf-8")
            digest = hashlib.sha256(body.encode()).hexdigest()
            if f.name in applied:
                if applied[f.name] != digest:
                    raise SystemExit(f"{f.name} changed after being applied; add a new migration instead")
                continue
            with conn.transaction():
                conn.execute(body)
                conn.execute("INSERT INTO schema_migrations (name, sha256) VALUES (%s, %s)", (f.name, digest))
            applied_now.append(f.name)
            if verbose:
                print(f"applied {f.name}")
    if verbose and not applied_now:
        print("up to date")
    return applied_now


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--status", action="store_true")
    args = ap.parse_args()
    if args.status:
        s = get_settings()
        with psycopg.connect(s.owner_database_url) as conn:
            conn.execute("CREATE TABLE IF NOT EXISTS schema_migrations ("
                         "name text PRIMARY KEY, sha256 text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())")
            done = {r[0] for r in conn.execute("SELECT name FROM schema_migrations")}
        for f in sorted(s.migrations_dir.glob("*.sql")):
            print(("applied " if f.name in done else "pending ") + f.name)
        return
    migrate()


if __name__ == "__main__":
    main()
