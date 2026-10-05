// Generic CRUD behaviour: validation, casting, audit trail, link tables, frozen versions.
import { describe, expect, it } from "vitest";
import { ALPHA, call, del, get, login, patch, post } from "./client";

describe("records", () => {
  it("meta describes every table, minus secrets", async () => {
    const m = (await get("/meta", await login("qse@alpha.test"))).body;
    const names = m.tables.map((t: any) => t.name);
    expect(names).toEqual(expect.arrayContaining(["nonconformities", "actions", "documents", "clauses"]));
    expect(names).not.toContain("invitations");
    const users = m.tables.find((t: any) => t.name === "users");
    expect(users.columns.map((c: any) => c.name)).not.toContain("auth_subject");
  });

  it("create, update, delete with an audit trail", async () => {
    const h = await login("qse@alpha.test");
    const base = `/orgs/${ALPHA}/t/interested_parties`;
    const r = await post(base, h, { name: "Banque", nature: "external", influence: 2 });
    expect(r.status).toBe(201);
    const row = r.body;
    expect(row).toMatchObject({ organization_id: ALPHA, is_relevant: true, _label: "Banque", created_by: "b0000000-0000-4000-8000-000000000003" });
    const u = await patch(`${base}/${row.id}`, h, { influence: 3 });
    expect(u.status).toBe(200);
    expect(u.body.influence).toBe(3);
    expect((await del(`${base}/${row.id}`, h)).status).toBe(204);
    expect((await get(`${base}/${row.id}`, h)).status).toBe(404);
    const log = (await get(`/t/activity_log?entity_id=${row.id}&order=occurred_at`, h)).body.items;
    expect(log.map((e: any) => e.action)).toEqual(["create", "update", "delete"]);
    expect(log[1].diff).toEqual({ before: { influence: 2 }, after: { influence: 3 } });
  });

  it("validates input", async () => {
    const h = await login("qse@alpha.test");
    const base = `/orgs/${ALPHA}/t/nonconformities`;
    const ok = { number: "N", title: "x", detected_on: "2026-01-01", source: "other" };
    let r = await post(base, h, { title: "x" });
    expect(r.status).toBe(400);
    expect(r.body.detail).toContain("number");
    r = await post(base, h, { ...ok, source: "bogus" });
    expect([r.status, r.body.column]).toEqual([400, "source"]);
    r = await post(base, h, { ...ok, detected_on: "not a date" });
    expect(r.status).toBe(400);
    r = await post(base, h, { ...ok, organization_id: ALPHA });
    expect([r.status, r.body.column]).toEqual([400, "organization_id"]);
    r = await post(base, h, { ...ok, number: "NC-2026-001" });
    expect(r.status).toBe(409);
    expect(r.body).toMatchObject({ error: "duplicate", column: "number", detail: "a record with the same number already exists" });
    r = await call("POST", base, h);
    expect(r.status).toBe(415);
  });

  it("filters, searches, orders and pages", async () => {
    const h = await login("qse@alpha.test");
    const base = `/orgs/${ALPHA}/t/nonconformities`;
    expect((await get(`${base}?severity=major`, h)).body.total).toBe(1);
    expect((await get(`${base}?q=coulisse`, h)).body.items[0].number).toBe("NC-2026-001");
    const page = (await get(`${base}?order=-number&limit=1`, h)).body;
    expect(page.total).toBe(2);
    expect(page.items.map((x: any) => x.number)).toEqual(["NC-2026-002"]);
    expect((await get(`${base}?nope=1`, h)).status).toBe(400);
    expect((await get(`${base}?order=nope`, h)).status).toBe(400);
  });

  it("supports filter operators", async () => {
    const h = await login("qse@alpha.test");
    const base = `/orgs/${ALPHA}/t/actions`;
    expect((await get(`${base}?status__in=planned,in_progress`, h)).body.total).toBe(2);
    expect((await get(`${base}?status__ne=planned`, h)).body.total).toBe(1);
    expect((await get(`${base}?due_on__lt=2026-10-01`, h)).body.items[0].number).toBe("AC-2026-001");
    expect((await get(`${base}?completed_on__isnull=true`, h)).body.total).toBe(2);
    expect((await get(`${base}?completed_on__isnull=false`, h)).body.total).toBe(0);
    expect((await get(`${base}?status__in=bogus`, h)).status).toBe(400);
    expect((await get(`${base}?status__like=x`, h)).status).toBe(400);
  });

  it("round-trips enum arrays", async () => {
    const h = await login("qse@alpha.test");
    const r = await post(`/orgs/${ALPHA}/t/context_issues`, h, { nature: "internal", title: "arr", systems: ["quality", "ohs"] });
    expect(r.status).toBe(201);
    expect(r.body.systems).toEqual(["quality", "ohs"]);
    expect((await get(`/orgs/${ALPHA}/t/context_issues?systems=ohs`, h)).body.total).toBeGreaterThan(0);
    expect((await post(`/orgs/${ALPHA}/t/context_issues`, h, { nature: "internal", title: "arr", systems: ["nope"] })).status).toBe(400);
  });

  it("creates and deletes link-table rows", async () => {
    const h = await login("qse@alpha.test");
    const clause = (await get("/t/clauses?number=8&limit=1", h)).body.items[0];
    const proc = "a2000000-0000-4000-8000-000000000003";
    const base = `/orgs/${ALPHA}/t/process_clauses`;
    expect((await post(base, h, { process_id: proc, clause_id: clause.id })).status).toBe(201);
    expect((await get(`${base}?process_id=${proc}`, h)).body.total).toBe(1);
    expect((await del(`${base}?process_id=${proc}&clause_id=${clause.id}`, h)).status).toBe(204);
    expect((await get(`${base}?process_id=${proc}`, h)).body.total).toBe(0);
  });

  it("rejects the wrong scope and protected tables", async () => {
    const h = await login("qse@alpha.test");
    expect((await get("/t/nonconformities", h)).status).toBe(400);
    expect((await get(`/orgs/${ALPHA}/t/clauses`, h)).status).toBe(400);
    expect((await get("/t/nope", h)).status).toBe(404);
    expect((await post("/t/users", h, { email: "x@y", full_name: "x" })).status).toBe(405);
    expect((await get("/t/invitations", h)).status).toBe(404);
    expect((await get(`/orgs/${ALPHA}/t/actions/not-a-uuid`, h)).status).toBe(404);
  });

  it("freezes approved document versions", async () => {
    const h = await login("qse@alpha.test");
    const type = (await get(`/orgs/${ALPHA}/t/document_types?code=PRO`, h)).body.items[0];
    const doc = (await post(`/orgs/${ALPHA}/t/documents`, h, { code: "PRO-QSE-001", title: "Maîtrise des documents", document_type_id: type.id })).body;
    const v = (await post(`/orgs/${ALPHA}/t/document_versions`, h, { document_id: doc.id, revision: "00", version_no: 1 })).body;
    const url = `/orgs/${ALPHA}/t/document_versions/${v.id}`;
    expect((await patch(url, h, { status: "approved" })).status).toBe(200);
    const r = await patch(url, h, { change_summary: "sneaky edit" });
    expect(r.status).toBe(409);
    expect(r.body.detail).toContain("read-only");
    expect((await del(url, h)).status).toBe(409);
  });
});
