"""Generic record endpoints for every table of the model.

  /orgs/{org_id}/t/{table}[/{id}]   organization data (tables with organization_id)
  /t/{table}[/{id}]                 firm library, global reference, platform tables

Link tables (composite primary key, no id) are created with POST and deleted with
DELETE on the collection, passing every key column as a query parameter.
"""

from typing import Any
from uuid import UUID

from fastapi import APIRouter, Body, HTTPException, Query, Request, Response

from .. import crud
from ..auth import UserId
from ..db import user_tx
from ..meta import Table, get_model

router = APIRouter(tags=["records"])

RESERVED = {"q", "order", "limit", "offset"}


def _table(name: str, org_id: UUID | None, *, write: bool = False) -> Table:
    t = get_model().table(name)
    if t is None:
        raise HTTPException(404, f"unknown table {name}")
    if t.is_tenant and org_id is None:
        raise HTTPException(400, f"{name} is organization data: use /orgs/{{org_id}}/t/{name}")
    if not t.is_tenant and org_id is not None:
        raise HTTPException(400, f"{name} is not organization data: use /t/{name}")
    if write and not t.writable:
        raise HTTPException(405, f"{name} cannot be written through the generic API")
    return t


def _filters(request: Request) -> dict[str, str]:
    return {k: v for k, v in request.query_params.items() if k not in RESERVED}


def _list(user_id: UUID, org_id: UUID | None, table: str, request: Request, q: str | None,
          order: str | None, limit: int, offset: int) -> dict:
    t = _table(table, org_id)
    with user_tx(user_id) as conn:
        return crud.list_rows(conn, get_model(), t, org_id, _filters(request), q, order, limit, offset)


def _get(user_id: UUID, org_id: UUID | None, table: str, id: UUID) -> dict:
    t = _table(table, org_id)
    if t.is_link:
        raise HTTPException(404, f"{table} has a composite key; list it with filters")
    with user_tx(user_id) as conn:
        row = crud.get_row(conn, get_model(), t, org_id, {"id": id})
    if row is None:
        raise HTTPException(404, "not found")
    return row


def _create(user_id: UUID, org_id: UUID | None, table: str, payload: dict[str, Any]) -> dict:
    t = _table(table, org_id, write=True)
    with user_tx(user_id) as conn:
        return crud.create_row(conn, get_model(), t, org_id, user_id, payload)


def _update(user_id: UUID, org_id: UUID | None, table: str, id: UUID, payload: dict[str, Any]) -> dict:
    t = _table(table, org_id, write=True)
    if t.is_link:
        raise HTTPException(405, f"{table} rows are links: delete and re-create them")
    with user_tx(user_id) as conn:
        row = crud.update_row(conn, get_model(), t, org_id, user_id, {"id": id}, payload)
    if row is None:
        raise HTTPException(404, "not found")
    return row


def _delete(user_id: UUID, org_id: UUID | None, table: str, key: dict[str, Any]) -> Response:
    t = _table(table, org_id, write=True)
    with user_tx(user_id) as conn:
        if not crud.delete_row(conn, get_model(), t, org_id, user_id, key):
            raise HTTPException(404, "not found")
    return Response(status_code=204)


# ---- organization data -----------------------------------------------------------------
@router.get("/orgs/{org_id}/t/{table}")
def org_list(org_id: UUID, table: str, request: Request, user_id: UserId, q: str | None = None,
             order: str | None = None, limit: int = Query(100, ge=1, le=crud.MAX_LIMIT),
             offset: int = Query(0, ge=0)) -> dict:
    return _list(user_id, org_id, table, request, q, order, limit, offset)


@router.post("/orgs/{org_id}/t/{table}", status_code=201)
def org_create(org_id: UUID, table: str, user_id: UserId, payload: dict[str, Any] = Body(...)) -> dict:
    return _create(user_id, org_id, table, payload)


@router.delete("/orgs/{org_id}/t/{table}", status_code=204)
def org_delete_link(org_id: UUID, table: str, request: Request, user_id: UserId) -> Response:
    if not _table(table, org_id).is_link:
        raise HTTPException(405, "use DELETE /orgs/{org_id}/t/{table}/{id}")
    return _delete(user_id, org_id, table, _filters(request))


@router.get("/orgs/{org_id}/t/{table}/{id}")
def org_get(org_id: UUID, table: str, id: UUID, user_id: UserId) -> dict:
    return _get(user_id, org_id, table, id)


@router.patch("/orgs/{org_id}/t/{table}/{id}")
def org_update(org_id: UUID, table: str, id: UUID, user_id: UserId,
               payload: dict[str, Any] = Body(...)) -> dict:
    return _update(user_id, org_id, table, id, payload)


@router.delete("/orgs/{org_id}/t/{table}/{id}", status_code=204)
def org_delete(org_id: UUID, table: str, id: UUID, user_id: UserId) -> Response:
    return _delete(user_id, org_id, table, {"id": id})


# ---- firm library, reference & platform tables -----------------------------------------
@router.get("/t/{table}")
def lib_list(table: str, request: Request, user_id: UserId, q: str | None = None,
             order: str | None = None, limit: int = Query(100, ge=1, le=crud.MAX_LIMIT),
             offset: int = Query(0, ge=0)) -> dict:
    return _list(user_id, None, table, request, q, order, limit, offset)


@router.post("/t/{table}", status_code=201)
def lib_create(table: str, user_id: UserId, payload: dict[str, Any] = Body(...)) -> dict:
    return _create(user_id, None, table, payload)


@router.delete("/t/{table}", status_code=204)
def lib_delete_link(table: str, request: Request, user_id: UserId) -> Response:
    if not _table(table, None).is_link:
        raise HTTPException(405, "use DELETE /t/{table}/{id}")
    return _delete(user_id, None, table, _filters(request))


@router.get("/t/{table}/{id}")
def lib_get(table: str, id: UUID, user_id: UserId) -> dict:
    return _get(user_id, None, table, id)


@router.patch("/t/{table}/{id}")
def lib_update(table: str, id: UUID, user_id: UserId, payload: dict[str, Any] = Body(...)) -> dict:
    return _update(user_id, None, table, id, payload)


@router.delete("/t/{table}/{id}", status_code=204)
def lib_delete(table: str, id: UUID, user_id: UserId) -> Response:
    return _delete(user_id, None, table, {"id": id})
