"""Translate database errors into HTTP responses.

The database is the final authority on tenancy (RLS, composite FKs) and integrity (uniques,
checks, triggers); the API reports its verdicts instead of duplicating them.
"""

import psycopg
from fastapi import Request
from fastapi.responses import JSONResponse
from psycopg import errors as pg

_STATUS: list[tuple[type[psycopg.Error], int, str]] = [
    (pg.InsufficientPrivilege, 403, "forbidden"),
    (pg.UniqueViolation, 409, "duplicate"),
    (pg.ForeignKeyViolation, 409, "reference_error"),
    (pg.RaiseException, 409, "rule_violation"),
    (pg.NotNullViolation, 400, "missing_value"),
    (pg.CheckViolation, 400, "check_failed"),
    (pg.DataError, 400, "invalid_value"),
]


def db_error_response(exc: psycopg.Error) -> JSONResponse:
    diag = exc.diag
    for cls, status, code in _STATUS:
        if isinstance(exc, cls):
            detail = diag.message_primary or str(exc)
            if isinstance(exc, pg.ForeignKeyViolation):
                # Covers both "parent missing" and "parent belongs to another organization".
                detail = ("referenced record does not exist in this organization"
                          if "insert or update" in (diag.message_primary or "")
                          else "record is still referenced by other records")
            return JSONResponse(status_code=status, content={
                "error": code, "detail": detail, "constraint": diag.constraint_name,
                "column": diag.column_name})
    raise exc


async def psycopg_exception_handler(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, psycopg.Error)
    return db_error_response(exc)
