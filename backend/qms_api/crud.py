"""Generic, metadata-driven CRUD over any table of the model.

All identifiers come from the model (never from the request) and all values are bound
parameters with an explicit cast to the column type, so enums, arrays, dates and numerics
are parsed by PostgreSQL itself. Tenancy is enforced twice: the organization filter here,
and RLS + composite foreign keys in the database.
"""

import json
from datetime import date, datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

import psycopg
from psycopg import sql

from .meta import SERVER_COLUMNS, Column, Model, Table

MAX_LIMIT = 500
# ?col=v (equality), ?col__ne=v, ?col__lt=v … ?col__in=a,b,c, ?col__isnull=true
FILTER_OPS = {"": "=", "ne": "<>", "lt": "<", "lte": "<=", "gt": ">", "gte": ">="}


class BadRequest(Exception):
    def __init__(self, detail: str, column: str | None = None):
        super().__init__(detail)
        self.detail = detail
        self.column = column


def _value(model: Model, col: Column, value: Any) -> Any:
    if value is None:
        if col.nn:
            raise BadRequest(f"{col.name} cannot be null", col.name)
        return None
    if col.base_type == "jsonb":
        return json.dumps(value)
    if col.is_array:
        if not isinstance(value, list):
            raise BadRequest(f"{col.name} must be a list", col.name)
        allowed = model.enums.get(col.base_type)
        if allowed is not None:
            for v in value:
                if v not in allowed:
                    raise BadRequest(f"{col.name}: {v!r} is not one of {allowed}", col.name)
        return [str(v) for v in value]
    allowed = model.enums.get(col.base_type)
    if allowed is not None and value not in allowed:
        raise BadRequest(f"{col.name}: {value!r} is not one of {allowed}", col.name)
    if isinstance(value, (dict, list)):
        raise BadRequest(f"{col.name} must be a scalar", col.name)
    if col.base_type == "boolean" and not isinstance(value, bool):
        raise BadRequest(f"{col.name} must be true or false", col.name)
    return str(value) if not isinstance(value, bool) else value


def _placeholder(model: Model, col: Column) -> sql.Composable:
    # Arrays travel as text[] and are cast element-wise (text[] -> enum[] works via I/O cast).
    return sql.SQL("%s::{}").format(sql.SQL(model.sql_type(col)))


def _check_payload(table: Table, payload: dict[str, Any]) -> None:
    for k in payload:
        if k in SERVER_COLUMNS:
            raise BadRequest(f"{k} is set by the server", k)
        if k not in table.columns:
            raise BadRequest(f"unknown column {k}", k)


def _select_list(table: Table, alias: str = "t") -> sql.Composable:
    # Enum arrays are cast to text[]: the driver does not know custom array types and would
    # otherwise return the raw '{a,b}' literal.
    cols = []
    for c in table.readable_columns():
        ref = sql.SQL("{}.{}").format(sql.Identifier(alias), sql.Identifier(c))
        if table.columns[c].is_array:
            ref = sql.SQL("{}::text[] AS {}").format(ref, sql.Identifier(c))
        cols.append(ref)
    cols.append(sql.SQL(table.label_sql(alias) + " AS _label"))
    return sql.SQL(", ").join(cols)


def _where_org(table: Table, org_id: UUID | None) -> tuple[list[sql.Composable], list[Any]]:
    if table.is_tenant:
        if org_id is None:
            raise BadRequest(f"{table.name} is organization data: use /orgs/{{org_id}}/t/{table.name}")
        return [sql.SQL("t.organization_id = %s")], [org_id]
    return [], []


def list_rows(conn: psycopg.Connection, model: Model, table: Table, org_id: UUID | None,
              filters: dict[str, str], q: str | None, order: str | None,
              limit: int = 100, offset: int = 0) -> dict[str, Any]:
    where, params = _where_org(table, org_id)
    for key, v in filters.items():
        k, _, op = key.partition("__")
        col = table.columns.get(k)
        if col is None or k not in table.readable_columns():
            raise BadRequest(f"cannot filter on {k}", key)
        ident = sql.Identifier(k)
        if op == "isnull" or (op == "" and v == "null"):
            null = op == "" or _parse_filter(table.columns[k], v, boolean=True)
            where.append(sql.SQL("t.{} IS NULL" if null else "t.{} IS NOT NULL").format(ident))
        elif col.is_array:
            if op:
                raise BadRequest(f"{k} is a list: only equality (contains) is supported", key)
            where.append(sql.SQL("%s::{} = ANY(t.{})").format(sql.SQL(col.base_type), ident))
            params.append(v)
        elif op == "in":
            values = [_value(model, col, _parse_filter(col, x)) for x in v.split(",") if x != ""]
            where.append(sql.SQL("t.{} = ANY(%s::{}[])").format(ident, sql.SQL(model.sql_type(col))))
            params.append(values)
        elif op in FILTER_OPS:
            where.append(sql.SQL("t.{} {} ").format(ident, sql.SQL(FILTER_OPS[op])) + _placeholder(model, col))
            params.append(_value(model, col, _parse_filter(col, v)))
        else:
            raise BadRequest(f"unknown filter operator {op}", key)
    if q:
        search = [sql.SQL("t.{} ILIKE %s").format(sql.Identifier(c)) for c in table.search_columns()]
        if search:
            where.append(sql.SQL("(") + sql.SQL(" OR ").join(search) + sql.SQL(")"))
            params.extend([f"%{q}%"] * len(search))
    order_sql = _order(table, order)
    limit = max(1, min(limit, MAX_LIMIT))
    query = sql.SQL("SELECT {cols}, count(*) OVER () AS _total FROM {tbl} t {where} ORDER BY {order} "
                    "LIMIT %s OFFSET %s").format(
        cols=_select_list(table), tbl=sql.Identifier(table.name),
        where=(sql.SQL("WHERE ") + sql.SQL(" AND ").join(where)) if where else sql.SQL(""),
        order=order_sql)
    rows = conn.execute(query, [*params, limit, max(0, offset)]).fetchall()
    total = rows[0].pop("_total") if rows else 0
    for r in rows[1:]:
        r.pop("_total")
    return {"items": rows, "total": total, "limit": limit, "offset": offset}


def _parse_filter(col: Column, v: str, boolean: bool = False) -> Any:
    if boolean or col.base_type == "boolean":
        if v.lower() not in ("true", "false"):
            raise BadRequest(f"{col.name} must be true or false", col.name)
        return v.lower() == "true"
    return v


def _order(table: Table, order: str | None) -> sql.Composable:
    if order:
        desc = order.startswith("-")
        name = order.lstrip("-")
        if name not in table.columns:
            raise BadRequest(f"cannot order by {name}", name)
        parts = [sql.SQL("t.{} {} NULLS LAST").format(sql.Identifier(name), sql.SQL("DESC" if desc else "ASC"))]
    elif "sort_order" in table.columns:
        parts = [sql.SQL("t.sort_order"), sql.SQL(table.label_sql("t"))]
    elif "created_at" in table.columns:
        parts = [sql.SQL("t.created_at DESC")]
    else:
        parts = []
    parts += [sql.SQL("t.{}").format(sql.Identifier(c)) for c in table.pk]
    return sql.SQL(", ").join(parts)


def _pk_where(model: Model, table: Table, key: dict[str, Any]) -> tuple[sql.Composable, list[Any]]:
    conds, params = [], []
    for c in table.pk:
        if c not in key:
            raise BadRequest(f"missing key column {c}", c)
        conds.append(sql.SQL("t.{} = ").format(sql.Identifier(c)) + _placeholder(model, table.columns[c]))
        params.append(_value(model, table.columns[c], key[c]))
    return sql.SQL(" AND ").join(conds), params


def get_row(conn: psycopg.Connection, model: Model, table: Table, org_id: UUID | None,
            key: dict[str, Any]) -> dict[str, Any] | None:
    where, params = _where_org(table, org_id)
    pk_sql, pk_params = _pk_where(model, table, key)
    where.append(pk_sql)
    query = sql.SQL("SELECT {cols} FROM {tbl} t WHERE {where}").format(
        cols=_select_list(table), tbl=sql.Identifier(table.name), where=sql.SQL(" AND ").join(where))
    return conn.execute(query, [*params, *pk_params]).fetchone()


def create_row(conn: psycopg.Connection, model: Model, table: Table, org_id: UUID | None,
               user_id: UUID, payload: dict[str, Any]) -> dict[str, Any]:
    _check_payload(table, payload)
    missing = [c.name for c in table.columns.values() if c.required_on_create and c.name not in payload]
    if missing:
        raise BadRequest(f"missing required fields: {', '.join(missing)}", missing[0])
    names, values, params = [], [], []
    if table.is_tenant:
        names.append("organization_id")
        values.append(sql.SQL("%s"))
        params.append(_where_org(table, org_id)[1][0])
    if "created_by" in table.columns:
        names.append("created_by")
        values.append(sql.SQL("%s"))
        params.append(user_id)
    for k, v in payload.items():
        col = table.columns[k]
        names.append(k)
        values.append(_placeholder(model, col))
        params.append(_value(model, col, v))
    query = sql.SQL("INSERT INTO {tbl} AS t ({names}) VALUES ({values}) RETURNING {cols}").format(
        tbl=sql.Identifier(table.name), names=sql.SQL(", ").join(map(sql.Identifier, names)),
        values=sql.SQL(", ").join(values), cols=_select_list(table))
    row = conn.execute(query, params).fetchone()
    assert row is not None
    log_activity(conn, table, org_id, user_id, "create", row, {"after": _jsonable(payload)})
    return row


def update_row(conn: psycopg.Connection, model: Model, table: Table, org_id: UUID | None,
               user_id: UUID, key: dict[str, Any], payload: dict[str, Any]) -> dict[str, Any] | None:
    _check_payload(table, payload)
    for c in table.pk:
        if c in payload:
            raise BadRequest(f"{c} is part of the key and cannot be changed", c)
    if not payload:
        return get_row(conn, model, table, org_id, key)
    before = get_row(conn, model, table, org_id, key)
    if before is None:
        return None
    sets, params = [], []
    for k, v in payload.items():
        col = table.columns[k]
        sets.append(sql.SQL("{} = ").format(sql.Identifier(k)) + _placeholder(model, col))
        params.append(_value(model, col, v))
    where, wparams = _where_org(table, org_id)
    pk_sql, pk_params = _pk_where(model, table, key)
    where.append(pk_sql)
    query = sql.SQL("UPDATE {tbl} AS t SET {sets} WHERE {where} RETURNING {cols}").format(
        tbl=sql.Identifier(table.name), sets=sql.SQL(", ").join(sets),
        where=sql.SQL(" AND ").join(where), cols=_select_list(table))
    row = conn.execute(query, [*params, *wparams, *pk_params]).fetchone()
    if row is None:
        # Visible but not writable (e.g. the client set firm access to read-only).
        raise PermissionError("read-only access to this record")
    changed = {k for k in payload if _jsonable(before.get(k)) != _jsonable(row.get(k))}
    if changed:
        log_activity(conn, table, org_id, user_id, "update", row,
                     {"before": {k: _jsonable(before.get(k)) for k in changed},
                      "after": {k: _jsonable(row.get(k)) for k in changed}})
    return row


def delete_row(conn: psycopg.Connection, model: Model, table: Table, org_id: UUID | None,
               user_id: UUID, key: dict[str, Any]) -> bool:
    before = get_row(conn, model, table, org_id, key)
    if before is None:
        return False
    where, params = _where_org(table, org_id)
    pk_sql, pk_params = _pk_where(model, table, key)
    where.append(pk_sql)
    query = sql.SQL("DELETE FROM {tbl} AS t WHERE {where}").format(
        tbl=sql.Identifier(table.name), where=sql.SQL(" AND ").join(where))
    if conn.execute(query, [*params, *pk_params]).rowcount == 0:
        raise PermissionError("read-only access to this record")
    log_activity(conn, table, org_id, user_id, "delete", before, {"before": _jsonable(before)})
    return True


def log_activity(conn: psycopg.Connection, table: Table, org_id: UUID | None, user_id: UUID,
                 action: str, row: dict[str, Any], diff: dict[str, Any]) -> None:
    """Append to the audit trail. Global reference tables (no firm) are not logged."""
    if table.is_tenant:
        firm = conn.execute("SELECT firm_id FROM organizations WHERE id = %s", (org_id,)).fetchone()
        firm_id = firm["firm_id"] if firm else None
    else:
        firm_id = row.get("firm_id")
        org_id = row.get("org_id") or (row.get("id") if table.name == "organizations" else None)
    if firm_id is None:
        return
    conn.execute(
        "INSERT INTO activity_log (firm_id, org_id, actor_user_id, action, entity_type, entity_id, diff) "
        "VALUES (%s, %s, %s, %s, %s, %s, %s::jsonb)",
        (firm_id, org_id, user_id, action, table.name, row.get("id"), json.dumps(diff)))


def _jsonable(v: Any) -> Any:
    if isinstance(v, dict):
        return {k: _jsonable(x) for k, x in v.items() if k != "_label"}
    if isinstance(v, list):
        return [_jsonable(x) for x in v]
    if isinstance(v, (UUID, date, datetime)):
        return v.isoformat() if not isinstance(v, UUID) else str(v)
    if isinstance(v, Decimal):
        return str(v)
    return v
