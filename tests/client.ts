// Calls the API in-process, exactly as the Next.js route does.
import { afterAll } from "vitest";
import { closePool } from "../lib/server/db";
import { handle } from "../lib/server/router";

export const ALPHA = "a0000000-0000-4000-8000-000000000002";
export const BETA = "a0000000-0000-4000-8000-000000000003";
export const INTERNAL = "a0000000-0000-4000-8000-000000000001";

type Res = { status: number; body: any };

export async function call(method: string, path: string, token?: string, body?: unknown): Promise<Res> {
  const headers: Record<string, string> = {};
  if (token) headers.authorization = `Bearer ${token}`;
  if (body !== undefined) headers["content-type"] = "application/json";
  const res = await handle(new Request(`http://test/api${path}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) }));
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}

const tokens = new Map<string, string>();
export async function login(email: string): Promise<string> {
  if (!tokens.has(email)) {
    const r = await call("POST", "/auth/dev-login", undefined, { email });
    if (r.status !== 200) throw new Error(`login ${email}: ${JSON.stringify(r.body)}`);
    tokens.set(email, r.body.access_token);
  }
  return tokens.get(email)!;
}

export const get = (path: string, t: string) => call("GET", path, t);
export const post = (path: string, t: string, body: unknown) => call("POST", path, t, body);
export const patch = (path: string, t: string, body: unknown) => call("PATCH", path, t, body);
export const del = (path: string, t: string) => call("DELETE", path, t);

afterAll(closePool);
