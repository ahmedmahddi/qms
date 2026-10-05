/**
 * The whole HTTP API, as one Request → Response function. app/api/[...path]/route.ts mounts it,
 * which keeps it a single serverless function on Vercel, and the tests call it directly.
 *
 *   POST /api/auth/dev-login · POST /api/auth/logout · GET /api/auth/config
 *   GET  /api/me · GET /api/meta · GET /api/health
 *   /api/orgs/{org}/t/{table}[/{id}]   organization data (tables with organization_id)
 *   /api/t/{table}[/{id}]              firm library, global reference and platform tables
 *
 * Link tables (composite key, no id) are created with POST and deleted with DELETE on the
 * collection, passing every key column as a query parameter.
 */
import { issueToken, sessionCookie, userIdFrom } from "./auth";
import { config } from "./config";
import { BadRequest, createRow, deleteRow, getRow, listRows, MAX_LIMIT, ReadOnly, updateRow } from "./crud";
import { anonTx, InactiveUser, userTx } from "./db";
import { dbErrorBody, isDbError } from "./errors";
import { model, publicMeta, type Table } from "./model";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const RESERVED = new Set(["q", "order", "limit", "offset"]);

class HttpError extends Error {
  constructor(readonly status: number, readonly detail: string, readonly code = "error") {
    super(detail);
  }
}

const json = (body: unknown, status = 200, headers: HeadersInit = {}) =>
  Response.json(body, { status, headers: { "Cache-Control": "no-store", ...headers } });

export async function handle(req: Request): Promise<Response> {
  try {
    return await route(req);
  } catch (e) {
    if (e instanceof HttpError) return json({ error: e.code, detail: e.detail }, e.status);
    if (e instanceof BadRequest) return json({ error: "bad_request", detail: e.detail, column: e.column }, 400);
    if (e instanceof ReadOnly) return json({ error: "forbidden", detail: e.message }, 403);
    if (e instanceof InactiveUser) return json({ error: "unauthorized", detail: "inactive user" }, 401);
    if (isDbError(e)) {
      const mapped = dbErrorBody(e);
      if (mapped) return json(mapped.body, mapped.status);
    }
    console.error(e);
    return json({ error: "internal", detail: "internal error" }, 500);
  }
}

async function route(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const parts = url.pathname.replace(/^\/api\/?/, "").split("/").filter(Boolean).map(decodeURIComponent);
  const m = req.method;
  const at = (...p: string[]) => p.length === parts.length && p.every((x, i) => x === "*" || x === parts[i]);

  if (at("health")) return json({ status: "ok" });
  if (at("auth", "config")) return json({ dev_auth: config.devAuth });
  if (at("auth", "dev-login") && m === "POST") return devLogin(req, url);
  if (at("auth", "logout") && m === "POST") return json({ ok: true }, 200, { "Set-Cookie": sessionCookie(null, url.protocol === "https:") });

  const userId = await userIdFrom(req);
  if (!userId) throw new HttpError(401, "not signed in", "unauthorized");

  if (at("me") && m === "GET") return json(await me(userId));
  if (at("meta") && m === "GET") return json(publicMeta());

  let orgId: string | null = null;
  let rest = parts;
  if (parts[0] === "orgs") {
    orgId = parts[1];
    if (!orgId || !UUID.test(orgId)) throw new HttpError(404, "not found");
    rest = parts.slice(2);
  }
  if (rest[0] === "t" && (rest.length === 2 || rest.length === 3)) {
    const id = rest[2] ?? null;
    if (id !== null && !UUID.test(id)) throw new HttpError(404, "not found");
    return records(req, url, userId, orgId, rest[1], id);
  }
  throw new HttpError(404, "not found");
}

async function readBody(req: Request): Promise<Record<string, unknown>> {
  // JSON only: also stops cross-site form posts riding on the session cookie.
  if (!req.headers.get("content-type")?.includes("application/json"))
    throw new HttpError(415, "send application/json", "unsupported_media_type");
  try {
    return await req.json();
  } catch {
    throw new BadRequest("invalid JSON body");
  }
}

async function devLogin(req: Request, url: URL): Promise<Response> {
  if (!config.devAuth) throw new HttpError(404, "not found");
  const { email } = await readBody(req);
  if (typeof email !== "string" || email.length < 3 || email.length > 320) throw new BadRequest("email is required", "email");
  const user = await anonTx(async (db) => {
    const { rows } = await db.query("SELECT * FROM app.user_for_login($1)", [email]);
    if (rows[0]?.status !== "active") return null;
    await db.query("SELECT app.record_login($1)", [rows[0].id]);
    return rows[0] as { id: string };
  });
  if (!user) throw new HttpError(401, "unknown or inactive user", "unauthorized");
  const token = await issueToken(user.id);
  return json({ access_token: token, token_type: "bearer" }, 200, {
    "Set-Cookie": sessionCookie(token, url.protocol === "https:"),
  });
}

const ORGS_SQL = `
SELECT o.id, o.name, o.type, o.firm_id, f.name AS firm_name, o.firm_access, o.status,
       app.is_org_member(o.id) AS is_member,
       app.is_firm_side(o.id)  AS is_firm_side,
       app.can_write_org(o.id) AS can_write,
       coalesce((SELECT array_agg(DISTINCT p.code ORDER BY p.code)
                 FROM org_memberships m
                 JOIN membership_roles mr ON mr.membership_id = m.id
                 JOIN role_permissions rp ON rp.role_id = mr.role_id
                 JOIN permissions p ON p.id = rp.permission_id
                 WHERE m.organization_id = o.id AND m.user_id = app.current_user_id() AND m.is_active),
                '{}') AS permissions
FROM organizations o
JOIN firms f ON f.id = o.firm_id
ORDER BY o.type <> 'internal', o.name`;

function me(userId: string) {
  return userTx(userId, async (db) => {
    const user = await db.query(
      "SELECT id, email, full_name, phone, locale, is_platform_admin, last_login_at FROM users WHERE id = $1", [userId]);
    const firms = await db.query(
      "SELECT f.id, f.name, fm.role, fm.title FROM firm_members fm JOIN firms f ON f.id = fm.firm_id " +
        "WHERE fm.user_id = $1 AND fm.is_active ORDER BY f.name", [userId]);
    const orgs = await db.query(ORGS_SQL);
    return { user: user.rows[0], firms: firms.rows, organizations: orgs.rows };
  });
}

function tableFor(name: string, orgId: string | null, write: boolean): Table {
  const t = model.table(name);
  if (!t) throw new HttpError(404, `unknown table ${name}`);
  if (t.isTenant && !orgId) throw new HttpError(400, `${name} is organization data: use /orgs/{org_id}/t/${name}`);
  if (!t.isTenant && orgId) throw new HttpError(400, `${name} is not organization data: use /t/${name}`);
  if (write && !t.writable) throw new HttpError(405, `${name} cannot be written through the generic API`);
  return t;
}

async function records(req: Request, url: URL, userId: string, orgId: string | null, name: string, id: string | null) {
  const m = req.method;
  const t = tableFor(name, orgId, m !== "GET");
  const query = Object.fromEntries(url.searchParams);
  const filters = Object.fromEntries(Object.entries(query).filter(([k]) => !RESERVED.has(k)));

  if (id === null) {
    if (m === "GET") {
      const limit = query.limit ? Number(query.limit) : 100;
      const offset = query.offset ? Number(query.offset) : 0;
      if (!Number.isInteger(limit) || limit < 1 || limit > MAX_LIMIT) throw new BadRequest(`limit must be 1..${MAX_LIMIT}`, "limit");
      if (!Number.isInteger(offset) || offset < 0) throw new BadRequest("offset must be ≥ 0", "offset");
      return json(await userTx(userId, (db) => listRows(db, t, orgId, { filters, q: query.q, order: query.order, limit, offset })));
    }
    if (m === "POST") {
      const body = await readBody(req);
      return json(await userTx(userId, (db) => createRow(db, t, orgId, userId, body)), 201);
    }
    if (m === "DELETE") {
      if (!t.isLink) throw new HttpError(405, "use DELETE …/t/{table}/{id}");
      const ok = await userTx(userId, (db) => deleteRow(db, t, orgId, userId, filters));
      if (!ok) throw new HttpError(404, "not found");
      return new Response(null, { status: 204 });
    }
  } else {
    if (t.isLink) throw new HttpError(404, `${name} has a composite key; use filters on the collection`);
    if (m === "GET") {
      const row = await userTx(userId, (db) => getRow(db, t, orgId, { id }));
      if (!row) throw new HttpError(404, "not found");
      return json(row);
    }
    if (m === "PATCH") {
      const body = await readBody(req);
      const row = await userTx(userId, (db) => updateRow(db, t, orgId, userId, { id }, body));
      if (!row) throw new HttpError(404, "not found");
      return json(row);
    }
    if (m === "DELETE") {
      const ok = await userTx(userId, (db) => deleteRow(db, t, orgId, userId, { id }));
      if (!ok) throw new HttpError(404, "not found");
      return new Response(null, { status: 204 });
    }
  }
  throw new HttpError(405, "method not allowed");
}
