/**
 * Generic, metadata-driven CRUD over any table of the model.
 *
 * Identifiers come only from the model (validated in model.ts), never from the request, and
 * every value is a bound parameter with an explicit cast to the column type, so PostgreSQL
 * itself parses enums, arrays, dates and numerics. Tenancy is enforced twice: the organization
 * filter here, and RLS + composite foreign keys in the database.
 */
import type { Row } from "../types";
import type { Db } from "./db";
import { type Col, model, SERVER_COLUMNS, type Table } from "./model";

export const MAX_LIMIT = 500;
/** ?col=v (equality), ?col__ne=v, ?col__lt=v … ?col__in=a,b,c, ?col__isnull=true */
const FILTER_OPS: Record<string, string> = { "": "=", ne: "<>", lt: "<", lte: "<=", gt: ">", gte: ">=" };

export class BadRequest extends Error {
  constructor(readonly detail: string, readonly column: string | null = null) {
    super(detail);
  }
}

export class ReadOnly extends Error {}

/** Collects bound parameters; `p(v, col)` returns the cast placeholder for a value. */
class Params {
  values: unknown[] = [];
  raw(v: unknown): string {
    this.values.push(v);
    return `$${this.values.length}`;
  }
  p(v: unknown, col: Col): string {
    return `${this.raw(toDb(col, v))}::${col.type}`;
  }
}

function toDb(col: Col, value: unknown): unknown {
  if (value === null || value === undefined) {
    if (col.nn) throw new BadRequest(`${col.name} cannot be null`, col.name);
    return null;
  }
  const allowed = model.enums[col.baseType];
  if (col.baseType === "jsonb") return JSON.stringify(value);
  if (col.isArray) {
    if (!Array.isArray(value)) throw new BadRequest(`${col.name} must be a list`, col.name);
    if (allowed) for (const v of value) checkEnum(col, v, allowed);
    return value.map(String);
  }
  if (allowed) checkEnum(col, value, allowed);
  if (typeof value === "object") throw new BadRequest(`${col.name} must be a scalar`, col.name);
  if (col.baseType === "boolean" && typeof value !== "boolean")
    throw new BadRequest(`${col.name} must be true or false`, col.name);
  return typeof value === "boolean" ? value : String(value);
}

function checkEnum(col: Col, v: unknown, allowed: string[]) {
  if (typeof v !== "string" || !allowed.includes(v))
    throw new BadRequest(`${col.name}: ${JSON.stringify(v)} is not one of ${allowed.join(", ")}`, col.name);
}

function parseBool(col: string, v: string): boolean {
  if (!["true", "false"].includes(v.toLowerCase())) throw new BadRequest(`${col} must be true or false`, col);
  return v.toLowerCase() === "true";
}

function selectList(t: Table, a = "t"): string {
  // Enum arrays are cast to text[] so the driver parses them into JS arrays.
  const cols = t.readableColumns().map((c) => (t.columns.get(c)!.isArray ? `${a}.${c}::text[] AS ${c}` : `${a}.${c}`));
  return [...cols, `${t.labelSql(a)} AS _label`].join(", ");
}

function orgWhere(t: Table, orgId: string | null, ps: Params): string[] {
  if (!t.isTenant) return [];
  if (!orgId) throw new BadRequest(`${t.name} is organization data: use /orgs/{org_id}/t/${t.name}`);
  return [`t.organization_id = ${ps.raw(orgId)}`];
}

function pkWhere(t: Table, key: Record<string, unknown>, ps: Params): string {
  return t.pk
    .map((c) => {
      if (!(c in key)) throw new BadRequest(`missing key column ${c}`, c);
      return `t.${c} = ${ps.p(key[c], t.columns.get(c)!)}`;
    })
    .join(" AND ");
}

function checkPayload(t: Table, payload: Record<string, unknown>) {
  if (typeof payload !== "object" || payload === null || Array.isArray(payload))
    throw new BadRequest("body must be a JSON object");
  for (const k of Object.keys(payload)) {
    if (SERVER_COLUMNS.has(k)) throw new BadRequest(`${k} is set by the server`, k);
    if (!t.columns.has(k)) throw new BadRequest(`unknown column ${k}`, k);
  }
}

export type ListOptions = {
  filters: Record<string, string>;
  q?: string | null;
  order?: string | null;
  limit?: number;
  offset?: number;
};

export async function listRows(db: Db, t: Table, orgId: string | null, opts: ListOptions) {
  const ps = new Params();
  const where = orgWhere(t, orgId, ps);
  const readable = new Set(t.readableColumns());
  for (const [key, v] of Object.entries(opts.filters)) {
    const [k, op = ""] = key.split("__", 2);
    const col = t.columns.get(k);
    if (!col || !readable.has(k)) throw new BadRequest(`cannot filter on ${k}`, key);
    if (op === "isnull" || (op === "" && v === "null")) {
      const isNull = op === "" || parseBool(key, v);
      where.push(`t.${k} IS ${isNull ? "" : "NOT "}NULL`);
    } else if (col.isArray) {
      if (op) throw new BadRequest(`${k} is a list: only equality (contains) is supported`, key);
      where.push(`${ps.raw(v)}::${col.baseType} = ANY(t.${k})`);
    } else if (op === "in") {
      const values = v.split(",").filter((x) => x !== "").map((x) => toDb(col, col.baseType === "boolean" ? parseBool(k, x) : x));
      where.push(`t.${k} = ANY(${ps.raw(values)}::${col.type}[])`);
    } else if (op in FILTER_OPS) {
      where.push(`t.${k} ${FILTER_OPS[op]} ${ps.p(col.baseType === "boolean" ? parseBool(k, v) : v, col)}`);
    } else {
      throw new BadRequest(`unknown filter operator ${op}`, key);
    }
  }
  if (opts.q) {
    const cols = t.searchColumns();
    if (cols.length) {
      const pat = ps.raw(`%${opts.q}%`);
      where.push(`(${cols.map((c) => `t.${c} ILIKE ${pat}`).join(" OR ")})`);
    }
  }
  const limit = Math.max(1, Math.min(opts.limit ?? 100, MAX_LIMIT));
  const offset = Math.max(0, opts.offset ?? 0);
  const sql =
    `SELECT ${selectList(t)}, count(*) OVER () AS _total FROM ${t.name} t ` +
    (where.length ? `WHERE ${where.join(" AND ")} ` : "") +
    `ORDER BY ${orderBy(t, opts.order)} LIMIT ${ps.raw(limit)} OFFSET ${ps.raw(offset)}`;
  const { rows } = await db.query(sql, ps.values);
  const total = rows.length ? Number(rows[0]._total) : 0;
  for (const r of rows) delete r._total;
  return { items: rows as Row[], total, limit, offset };
}

function orderBy(t: Table, order?: string | null): string {
  let parts: string[];
  if (order) {
    const desc = order.startsWith("-");
    const name = order.replace(/^-/, "");
    if (!t.columns.has(name)) throw new BadRequest(`cannot order by ${name}`, name);
    parts = [`t.${name} ${desc ? "DESC" : "ASC"} NULLS LAST`];
  } else if (t.columns.has("sort_order")) parts = ["t.sort_order", t.labelSql("t")];
  else if (t.columns.has("created_at")) parts = ["t.created_at DESC"];
  else parts = [];
  return [...parts, ...t.pk.map((c) => `t.${c}`)].join(", ");
}

export async function getRow(db: Db, t: Table, orgId: string | null, key: Record<string, unknown>): Promise<Row | null> {
  const ps = new Params();
  const where = [...orgWhere(t, orgId, ps), pkWhere(t, key, ps)];
  const { rows } = await db.query(`SELECT ${selectList(t)} FROM ${t.name} t WHERE ${where.join(" AND ")}`, ps.values);
  return rows[0] ?? null;
}

export async function createRow(db: Db, t: Table, orgId: string | null, userId: string, payload: Record<string, unknown>) {
  checkPayload(t, payload);
  const missing = [...t.columns.values()].filter((c) => c.requiredOnCreate && !(c.name in payload)).map((c) => c.name);
  if (missing.length) throw new BadRequest(`missing required fields: ${missing.join(", ")}`, missing[0]);
  const ps = new Params();
  const names: string[] = [];
  const values: string[] = [];
  if (t.isTenant) {
    if (!orgId) throw new BadRequest(`${t.name} is organization data`);
    names.push("organization_id");
    values.push(ps.raw(orgId));
  }
  if (t.columns.has("created_by")) {
    names.push("created_by");
    values.push(ps.raw(userId));
  }
  for (const [k, v] of Object.entries(payload)) {
    names.push(k);
    values.push(ps.p(v, t.columns.get(k)!));
  }
  const { rows } = await db.query(
    `INSERT INTO ${t.name} AS t (${names.join(", ")}) VALUES (${values.join(", ")}) RETURNING ${selectList(t)}`,
    ps.values,
  );
  await logActivity(db, t, orgId, userId, "create", rows[0], { after: payload });
  return rows[0] as Row;
}

export async function updateRow(
  db: Db, t: Table, orgId: string | null, userId: string, key: Record<string, unknown>, payload: Record<string, unknown>,
): Promise<Row | null> {
  checkPayload(t, payload);
  for (const c of t.pk) if (c in payload) throw new BadRequest(`${c} is part of the key and cannot be changed`, c);
  const before = await getRow(db, t, orgId, key);
  if (!before || !Object.keys(payload).length) return before;
  const ps = new Params();
  const sets = Object.entries(payload).map(([k, v]) => `${k} = ${ps.p(v, t.columns.get(k)!)}`);
  const where = [...orgWhere(t, orgId, ps), pkWhere(t, key, ps)];
  const { rows } = await db.query(
    `UPDATE ${t.name} AS t SET ${sets.join(", ")} WHERE ${where.join(" AND ")} RETURNING ${selectList(t)}`,
    ps.values,
  );
  // Visible but not writable (e.g. the client set the firm's access to read-only).
  if (!rows[0]) throw new ReadOnly("read-only access to this record");
  const row = rows[0] as Row;
  const changed = Object.keys(payload).filter((k) => JSON.stringify(before[k]) !== JSON.stringify(row[k]));
  if (changed.length)
    await logActivity(db, t, orgId, userId, "update", row, {
      before: Object.fromEntries(changed.map((k) => [k, before[k]])),
      after: Object.fromEntries(changed.map((k) => [k, row[k]])),
    });
  return row;
}

export async function deleteRow(db: Db, t: Table, orgId: string | null, userId: string, key: Record<string, unknown>) {
  const before = await getRow(db, t, orgId, key);
  if (!before) return false;
  const ps = new Params();
  const where = [...orgWhere(t, orgId, ps), pkWhere(t, key, ps)];
  const res = await db.query(`DELETE FROM ${t.name} AS t WHERE ${where.join(" AND ")}`, ps.values);
  if (!res.rowCount) throw new ReadOnly("read-only access to this record");
  const { _label, ...rest } = before;
  await logActivity(db, t, orgId, userId, "delete", before, { before: rest });
  return true;
}

/** Append to the audit trail. Global reference tables (no firm) are not logged. */
async function logActivity(db: Db, t: Table, orgId: string | null, userId: string, action: string, row: Row, diff: unknown) {
  let firmId: unknown;
  if (t.isTenant) {
    const { rows } = await db.query("SELECT firm_id FROM organizations WHERE id = $1", [orgId]);
    firmId = rows[0]?.firm_id;
  } else {
    firmId = row.firm_id;
    orgId = (row.org_id as string) ?? (t.name === "organizations" ? (row.id as string) : null);
  }
  if (!firmId) return;
  await db.query(
    "INSERT INTO activity_log (firm_id, org_id, actor_user_id, action, entity_type, entity_id, diff) VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)",
    [firmId, orgId, userId, action, t.name, row.id ?? null, JSON.stringify(diff)],
  );
}
