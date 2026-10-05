"""Connection pool and per-request transactions.

Every request runs in one transaction with `app.user_id` set locally, which is what the
RLS policies read through app.current_user_id(). Nothing outside `user_tx` / `anon_tx`
touches the database.
"""

from collections.abc import Iterator
from contextlib import contextmanager
from uuid import UUID

import psycopg
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from .config import get_settings

_pool: ConnectionPool | None = None


def open_pool() -> ConnectionPool:
    global _pool
    if _pool is None:
        _pool = ConnectionPool(get_settings().database_url, min_size=1, max_size=10,
                               kwargs={"row_factory": dict_row}, open=True)
    return _pool


def close_pool() -> None:
    global _pool
    if _pool is not None:
        _pool.close()
        _pool = None


class InactiveUser(Exception):
    """The token is valid but the user no longer exists or was archived."""


@contextmanager
def user_tx(user_id: UUID) -> Iterator[psycopg.Connection]:
    """A transaction acting as `user_id`: RLS policies see this user."""
    with open_pool().connection() as conn, conn.transaction():
        conn.execute("SELECT set_config('app.user_id', %s, true)", (str(user_id),))
        row = conn.execute("SELECT status FROM users WHERE id = %s", (user_id,)).fetchone()
        if row is None or row["status"] != "active":
            raise InactiveUser()
        yield conn


@contextmanager
def anon_tx() -> Iterator[psycopg.Connection]:
    """A transaction with no user: only the SECURITY DEFINER login helpers are useful here."""
    with open_pool().connection() as conn, conn.transaction():
        conn.execute("SELECT set_config('app.user_id', '', true)")
        yield conn
