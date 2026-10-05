import type { TableMeta } from "../types";

export class ApiError extends Error {
  constructor(
    public status: number,
    public detail: string,
    public column: string | null = null,
  ) {
    super(detail);
  }
}

/** Same-origin call to the API; the session travels in an httpOnly cookie. */
export async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers);
  if (init.body) headers.set("Content-Type", "application/json");
  const res = await fetch(`/api${path}`, { ...init, headers, credentials: "same-origin" });
  if (res.status === 401 && !location.pathname.startsWith("/login")) location.assign("/login");
  if (!res.ok) {
    let body: { detail?: unknown; column?: string } = {};
    try {
      body = await res.json();
    } catch {
      /* not JSON */
    }
    const detail = typeof body.detail === "string" ? body.detail : JSON.stringify(body.detail ?? res.statusText);
    throw new ApiError(res.status, detail, body.column ?? null);
  }
  return res.status === 204 ? (undefined as T) : ((await res.json()) as T);
}

/** Base path of a table's records: organization data lives under its org, the rest is global. */
export function tablePath(table: TableMeta, orgId: string): string {
  return table.tenant ? `/orgs/${orgId}/t/${table.name}` : `/t/${table.name}`;
}

export function qs(params: Record<string, string | number | undefined | null>): string {
  const p = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== null && v !== "") p.set(k, String(v));
  const s = p.toString();
  return s ? `?${s}` : "";
}
