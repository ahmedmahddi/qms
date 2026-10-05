"""Load db/seed/<name>.sql as the schema owner (default: dev)."""

import sys

import psycopg

from .config import REPO_ROOT, get_settings


def seed(name: str = "dev", owner_url: str | None = None) -> None:
    body = (REPO_ROOT / "db" / "seed" / f"{name}.sql").read_text(encoding="utf-8")
    with psycopg.connect(owner_url or get_settings().owner_database_url, autocommit=True) as conn:
        conn.execute(body)


if __name__ == "__main__":
    seed(sys.argv[1] if len(sys.argv) > 1 else "dev")
    print("seeded")
