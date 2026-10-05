// Who can see and change what. These are the guarantees clients are sold on.
import { describe, expect, it } from "vitest";
import { ALPHA, BETA, call, del, get, INTERNAL, login, patch, post } from "./client";

const ALPHA_NC = "a3000000-0000-4000-8000-000000000001";

async function orgs(token: string): Promise<Record<string, any>> {
  const r = await get("/me", token);
  return Object.fromEntries(r.body.organizations.map((o: any) => [o.id, o]));
}

async function ncNumbers(token: string, org: string): Promise<string[]> {
  const r = await get(`/orgs/${org}/t/nonconformities`, token);
  expect(r.status).toBe(200);
  return r.body.items.map((x: any) => x.number).sort();
}

describe("tenancy", () => {
  it("requires a valid session", async () => {
    expect((await call("GET", "/me")).status).toBe(401);
    expect((await get(`/orgs/${ALPHA}/t/actions`, "nope")).status).toBe(401);
    expect((await call("POST", "/auth/dev-login", undefined, { email: "nobody@x.test" })).status).toBe(401);
  });

  it("client users only see their own organization", async () => {
    const alpha = await login("qse@alpha.test");
    const beta = await login("qse@beta.test");
    expect(Object.keys(await orgs(alpha))).toEqual([ALPHA]);
    expect(Object.keys(await orgs(beta))).toEqual([BETA]);
    expect(await ncNumbers(alpha, ALPHA)).toEqual(["NC-2026-001", "NC-2026-002"]);
    expect(await ncNumbers(alpha, BETA)).toEqual([]);
    expect(await ncNumbers(beta, ALPHA)).toEqual([]);
  });

  it("another tenant's record is not found", async () => {
    expect((await get(`/orgs/${ALPHA}/t/nonconformities/${ALPHA_NC}`, await login("qse@alpha.test"))).status).toBe(200);
    const beta = await login("qse@beta.test");
    expect((await get(`/orgs/${BETA}/t/nonconformities/${ALPHA_NC}`, beta)).status).toBe(404);
    expect((await get(`/orgs/${ALPHA}/t/nonconformities/${ALPHA_NC}`, beta)).status).toBe(404);
    expect((await patch(`/orgs/${ALPHA}/t/nonconformities/${ALPHA_NC}`, beta, { title: "pwned" })).status).toBe(404);
  });

  it("cannot insert into another tenant", async () => {
    const r = await post(`/orgs/${ALPHA}/t/context_issues`, await login("qse@beta.test"), { nature: "internal", title: "x" });
    expect(r.status).toBe(403);
  });

  it("cannot reference another tenant's record (composite FK)", async () => {
    const r = await post(`/orgs/${BETA}/t/actions`, await login("qse@beta.test"), {
      number: "AC-X", title: "x", type: "corrective", nonconformity_id: ALPHA_NC,
    });
    expect(r.status).toBe(409);
    expect(r.body.error).toBe("reference_error");
  });

  it("firm owner sees every client, a consultant only assigned ones", async () => {
    expect(Object.keys(await orgs(await login("owner@atlas.test"))).sort()).toEqual([INTERNAL, ALPHA, BETA].sort());
    const consultant = await login("consultant@atlas.test");
    expect(Object.keys(await orgs(consultant))).toEqual([ALPHA]);
    expect(await ncNumbers(consultant, BETA)).toEqual([]);
  });

  it("read-only firm access blocks firm writes", async () => {
    const owner = await login("owner@atlas.test");
    const beta = (await orgs(owner))[BETA];
    expect(beta.firm_access).toBe("read_only");
    expect(beta.can_write).toBe(false);
    expect(await ncNumbers(owner, BETA)).toEqual(["NC-2026-001"]);
    expect((await post(`/orgs/${BETA}/t/context_issues`, owner, { nature: "internal", title: "x" })).status).toBe(403);
    const nc = (await get(`/orgs/${BETA}/t/nonconformities`, owner)).body.items[0];
    expect((await patch(`/orgs/${BETA}/t/nonconformities/${nc.id}`, owner, { title: "x" })).status).toBe(403);
    expect((await del(`/orgs/${BETA}/t/nonconformities/${nc.id}`, owner)).status).toBe(403);
  });

  it("only the client can change the firm's access", async () => {
    const owner = await login("owner@atlas.test");
    expect((await patch(`/t/organizations/${ALPHA}`, owner, { firm_access: "none" })).status).toBe(409);
    const beta = await login("qse@beta.test");
    expect((await patch(`/t/organizations/${BETA}`, beta, { firm_access: "none" })).status).toBe(200);
    try {
      expect(Object.keys(await orgs(owner))).not.toContain(BETA);
    } finally {
      expect((await patch(`/t/organizations/${BETA}`, beta, { firm_access: "read_only" })).status).toBe(200);
    }
  });

  it("firm-internal comments are hidden from client users", async () => {
    const consultant = await login("consultant@atlas.test");
    const alpha = await login("qse@alpha.test");
    for (const visibility of ["shared", "firm_internal"]) {
      const r = await post(`/orgs/${ALPHA}/t/comments`, consultant, {
        entity_type: "nonconformities", entity_id: ALPHA_NC, body: `${visibility} note`, visibility,
      });
      expect(r.status).toBe(201);
    }
    const bodies = async (t: string) =>
      (await get(`/orgs/${ALPHA}/t/comments?entity_id=${ALPHA_NC}`, t)).body.items.map((c: any) => c.body);
    expect(await bodies(alpha)).toContain("shared note");
    expect(await bodies(alpha)).not.toContain("firm_internal note");
    expect(await bodies(consultant)).toEqual(expect.arrayContaining(["shared note", "firm_internal note"]));
    const r = await post(`/orgs/${ALPHA}/t/comments`, alpha, {
      entity_type: "nonconformities", entity_id: ALPHA_NC, body: "x", visibility: "firm_internal",
    });
    expect(r.status).toBe(403);
  });
});
