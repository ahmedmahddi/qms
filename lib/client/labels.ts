import type { Column, Meta, TableMeta } from "../types";

const ACRONYMS: Record<string, string> = {
  nc: "NC", ohs: "OHS", qse: "QSE", ppe: "PPE", rca: "RCA", ip: "IP", url: "URL", sha256: "SHA-256", pv: "PV",
};

export function humanize(name: string): string {
  const words = name.replace(/_id$/, "").split("_");
  return words
    .map((w, i) => ACRONYMS[w] ?? (i === 0 ? w.charAt(0).toUpperCase() + w.slice(1) : w))
    .join(" ");
}

export const columnLabel = (c: Column) => humanize(c.name);

/**
 * Tables shown in the navigation. Child rows (a required link to another table of the same
 * domain, e.g. action_updates → actions) and pure link tables are reached from their parent's
 * "Related" panel instead, which keeps ~150 tables down to the registers people actually open.
 */
export function isPrimary(meta: Meta, t: TableMeta): boolean {
  if (t.link) return false;
  return !t.columns.some((c) => {
    if (!c.fk || !c.nn || c.name === "organization_id") return false;
    const parent = meta.tables.find((x) => x.name === c.fk);
    return !!parent && parent.domain === t.domain;
  });
}

const LONG_TEXT = /(description|summary|text|notes?|content|comment|statement|purpose|scope|requirement|finding|evidence|recommendation|cause|consequence|containment|rca|minutes|agenda|next_steps|responsibilities|mission|authorities|boundaries|justification|impact|criteria|body|answer|details)$/;

export function isLongText(c: Column): boolean {
  return c.base_type === "text" && !c.array && LONG_TEXT.test(c.name);
}

/** Columns worth showing in a list view, in order. */
export function listColumns(t: TableMeta): Column[] {
  const skip = new Set(["id", "organization_id", "created_at", "updated_at", "created_by"]);
  const preferred = ["code", "number", "reference", "name", "title", "label", "full_name", "email"];
  const cols = t.columns.filter((c) => !skip.has(c.name) && c.base_type !== "jsonb" && !isLongText(c));
  const head = preferred.map((p) => cols.find((c) => c.name === p)).filter((c): c is Column => !!c);
  const rest = cols.filter((c) => !head.includes(c));
  const score = (c: Column) =>
    (c.enum ? 0 : 10) + (["date", "timestamptz"].includes(c.base_type) ? 1 : 0) + (c.fk ? 3 : 0) + (c.nn ? 0 : 2);
  rest.sort((a, b) => score(a) - score(b));
  return [...head, ...rest].slice(0, 7);
}
