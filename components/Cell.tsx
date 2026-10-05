"use client";
import type { Column } from "@/lib/types";
import { useLabelOf } from "./lookups";

export function Cell({ col, value, orgId }: { col: Column; value: unknown; orgId: string }) {
  if (col.fk) return <FkCell table={col.fk} value={value} orgId={orgId} />;
  if (value == null || value === "") return <span className="muted">—</span>;
  if (col.enum && !col.array) return <span className={`badge b-${String(value)}`}>{String(value).replace(/_/g, " ")}</span>;
  if (Array.isArray(value)) return <>{value.map((v) => String(v).replace(/_/g, " ")).join(", ")}</>;
  if (typeof value === "boolean") return <>{value ? "✓" : "—"}</>;
  if (col.base_type === "timestamptz") return <>{new Date(String(value)).toLocaleString()}</>;
  if (col.base_type === "date") return <>{new Date(String(value) + "T00:00:00").toLocaleDateString()}</>;
  if (typeof value === "object") return <span className="mono">{JSON.stringify(value).slice(0, 60)}</span>;
  return <>{String(value)}</>;
}

function FkCell({ table, value, orgId }: { table: string; value: unknown; orgId: string }) {
  const labelOf = useLabelOf(table, orgId);
  if (value == null) return <span className="muted">—</span>;
  return <>{labelOf(value)}</>;
}
