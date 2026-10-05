/**
 * Translate database errors into HTTP responses. The database is the final authority on
 * tenancy (RLS, composite FKs) and integrity (uniques, checks, triggers); the API reports its
 * verdicts instead of duplicating them.
 */
import type { DatabaseError } from "pg";
import { model } from "./model";

const BY_CODE: [RegExp, number, string][] = [
  [/^42501$/, 403, "forbidden"], // insufficient privilege, incl. RLS WITH CHECK
  [/^23505$/, 409, "duplicate"],
  [/^23503$/, 409, "reference_error"],
  [/^P0001$/, 409, "rule_violation"], // RAISE EXCEPTION in a trigger
  [/^23502$/, 400, "missing_value"],
  [/^23514$/, 400, "check_failed"],
  [/^22/, 400, "invalid_value"], // data exceptions: bad dates, numbers, enum input…
];

export function isDbError(e: unknown): e is DatabaseError {
  return e instanceof Error && typeof (e as DatabaseError).code === "string" && "severity" in e;
}

/** RLS tables omit key values from unique-violation details, so name the columns from the model. */
function uniqueColumns(table?: string, constraint?: string): string[] {
  const t = table ? model.tables.get(table) : undefined;
  if (!t || !constraint) return [];
  const candidates = [...[...t.columns.values()].filter((c) => c.uq).map((c) => [c.name]), ...t.uniques];
  for (const cols of candidates)
    if (`${t.name}_${cols.join("_")}_key`.slice(0, 63) === constraint) {
      const shown = cols.filter((c) => c !== "organization_id");
      return shown.length ? shown : cols;
    }
  return [];
}

export function dbErrorBody(e: DatabaseError): { status: number; body: Record<string, unknown> } | null {
  const hit = BY_CODE.find(([re]) => re.test(e.code ?? ""));
  if (!hit) return null;
  const [, status, error] = hit;
  let detail = e.message;
  let column = e.column ?? null;
  if (e.code === "23505") {
    const cols = uniqueColumns(e.table, e.constraint);
    if (cols.length) {
      column = cols[0];
      detail = `a record with the same ${cols.join(", ")} already exists`;
    }
  } else if (e.code === "23503") {
    // Covers both "parent missing" and "parent belongs to another organization".
    detail = e.message.includes("insert or update")
      ? "referenced record does not exist in this organization"
      : "record is still referenced by other records";
  }
  return { status, body: { error, detail, constraint: e.constraint ?? null, column } };
}
