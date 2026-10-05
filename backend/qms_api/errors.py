"""Translate database errors into HTTP responses.

The database is the final authority on tenancy (RLS, composite FKs) and integrity (uniques,
checks, triggers); the API reports its verdicts instead of duplicating them.
"""

import psycopg
from fastapi import Request
from fastapi.responses import JSONResponse
from psycopg import errors as pg

from .meta import get_model

_STATUS: list[tuple[type[psycopg.Error], int, str]] = [
    (pg.InsufficientPrivilege, 403, "forbidden"),
    (pg.UniqueViolation, 409, "duplicate"),
    (pg.ForeignKeyViolation, 409, "reference_error"),
    (pg.RaiseException, 409, "rule_violation"),
    (pg.NotNullViolation, 400, "missing_value"),
    (pg.CheckViolation, 400, "check_failed"),
    (pg.DataError, 400, "invalid_value"),
]


def _unique_columns(table: str | None, constraint: str | None) -> list[str]:
    t = get_model().tables.get(table or "")
    if t is None or not constraint:
        return []
    candidates = [[c.name] for c in t.columns.values() if c.uq] + [list(u) for u in t.uniques]
    for cols in candidates:
        if f"{t.name}_{'_'.join(cols)}_key"[:63] == constraint:
            return [c for c in cols if c != "organization_id"] or cols
    return []


def db_error_response(exc: psycopg.Error) -> JSONResponse:
    diag = exc.diag
    for cls, status, code in _STATUS:
        if isinstance(exc, cls):
            detail = diag.message_primary or str(exc)
            column = diag.column_name
            if isinstance(exc, pg.UniqueViolation):
                # RLS tables omit the key values from the error (they could reveal hidden rows),
                # so name the columns from the model instead.
                cols = _unique_columns(diag.table_name, diag.constraint_name)
                if cols:
                    column = cols[0]
                    detail = f"a record with the same {', '.join(cols)} already exists"
            if isinstance(exc, pg.ForeignKeyViolation):
                # Covers both "parent missing" and "parent belongs to another organization".
                detail = ("referenced record does not exist in this organization"
                          if "insert or update" in (diag.message_primary or "")
                          else "record is still referenced by other records")
            return JSONResponse(status_code=status, content={
                "error": code, "detail": detail, "constraint": diag.constraint_name,
                "column": column})
    raise exc


async def psycopg_exception_handler(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, psycopg.Error)
    return db_error_response(exc)
