"use client";
import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams, usePathname, useRouter, useSearchParams } from "next/navigation";
import { api, ApiError, qs, tablePath } from "@/lib/client/api";
import { Cell } from "@/components/Cell";
import { useLabelOf } from "@/components/lookups";
import { columnLabel, humanize, listColumns } from "@/lib/client/labels";
import { useCurrentOrg, useMeta, useOrgId, useTable } from "@/lib/client/session";
import type { Page, TableMeta } from "@/lib/types";

const PAGE = 50;
const RESERVED = new Set(["q", "order", "offset"]);

export default function TableList() {
  const orgId = useOrgId();
  const { table: name } = useParams<{ table: string }>();
  const table = useTable(name);
  const { data: meta } = useMeta();
  if (!meta) return null;
  if (!table) return <div className="page">Unknown register.</div>;
  return <List key={table.name} orgId={orgId} table={table} />;
}

function List({ orgId, table }: { orgId: string; table: TableMeta }) {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const setParams = (next: URLSearchParams, opts?: { replace?: boolean }) =>
    (opts?.replace ? router.replace : router.push)(`${pathname}${next.size ? `?${next}` : ""}`, { scroll: false });
  const org = useCurrentOrg();
  const [search, setSearch] = useState(params.get("q") ?? "");
  const offset = Number(params.get("offset") ?? 0);
  const order = params.get("order") ?? "";
  const filters = Object.fromEntries([...params.entries()].filter(([k]) => !RESERVED.has(k)));
  const cols = listColumns(table);

  useEffect(() => {
    const id = setTimeout(() => {
      if ((params.get("q") ?? "") !== search) {
        const next = new URLSearchParams(params);
        if (search) next.set("q", search);
        else next.delete("q");
        next.delete("offset");
        setParams(next, { replace: true });
      }
    }, 250);
    return () => clearTimeout(id);
  }, [search, params, setParams]);

  const query = useQuery({
    queryKey: ["list", orgId, table.name, params.toString()],
    placeholderData: keepPreviousData,
    queryFn: () =>
      api<Page>(`${tablePath(table, orgId)}${qs({ ...filters, q: params.get("q"), order, limit: PAGE, offset })}`),
  });

  const setParam = (k: string, v: string | null) => {
    const next = new URLSearchParams(params);
    if (v) next.set(k, v);
    else next.delete(k);
    if (k !== "offset") next.delete("offset");
    setParams(next);
  };

  const canCreate = table.writable && (!table.tenant || org?.can_write);
  const page = query.data;

  return (
    <div className="page">
      <div className="page-head">
        <div>
          <h1>{humanize(table.name)}</h1>
          <p className="muted">{table.desc}</p>
        </div>
        {canCreate ? (
          <Link className="button" href={`/o/${orgId}/${table.name}/new${qs(filters)}`}>
            New
          </Link>
        ) : null}
      </div>
      <div className="toolbar">
        <input placeholder="Search…" value={search} onChange={(e) => setSearch(e.target.value)} />
        {Object.entries(filters).map(([k, v]) => (
          <FilterChip key={k} table={table} orgId={orgId} name={k} value={v} onClear={() => setParam(k, null)} />
        ))}
        <span className="spacer" />
        {page ? <span className="muted">{page.total} records</span> : null}
      </div>
      {query.error ? <p className="error">{(query.error as ApiError).detail ?? String(query.error)}</p> : null}
      <div className="table-wrap">
        <table className="grid">
          <thead>
            <tr>
              {cols.map((c) => {
                const active = order.replace("-", "") === c.name;
                return (
                  <th key={c.name} onClick={() => setParam("order", active && !order.startsWith("-") ? `-${c.name}` : c.name)}>
                    {columnLabel(c)}
                    {active ? (order.startsWith("-") ? " ↓" : " ↑") : ""}
                  </th>
                );
              })}
            </tr>
          </thead>
          <tbody>
            {page?.items.map((r, i) => (
              <tr
                key={String(r.id ?? i)}
                className={table.link ? "" : "clickable"}
                onClick={() => !table.link && router.push(`/o/${orgId}/${table.name}/${r.id}`)}
              >
                {cols.map((c) => (
                  <td key={c.name}>
                    <Cell col={c} value={r[c.name]} orgId={orgId} />
                  </td>
                ))}
              </tr>
            ))}
            {page && !page.items.length ? (
              <tr>
                <td colSpan={cols.length} className="muted empty">
                  Nothing here yet.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
      {page && page.total > PAGE ? (
        <div className="pager">
          <button className="ghost" disabled={offset === 0} onClick={() => setParam("offset", String(Math.max(0, offset - PAGE)))}>
            ← Previous
          </button>
          <span className="muted">
            {offset + 1}–{Math.min(offset + PAGE, page.total)} of {page.total}
          </span>
          <button className="ghost" disabled={offset + PAGE >= page.total} onClick={() => setParam("offset", String(offset + PAGE))}>
            Next →
          </button>
        </div>
      ) : null}
    </div>
  );
}

function FilterChip(props: { table: TableMeta; orgId: string; name: string; value: string; onClear: () => void }) {
  const [colName, op] = props.name.split("__");
  const col = props.table.columns.find((c) => c.name === colName);
  const labelOf = useLabelOf(col?.fk ?? null, props.orgId);
  const shown = col?.fk ? labelOf(props.value) : props.value.replace(/_/g, " ").replace(/,/g, ", ");
  return (
    <span className="chip on">
      {col ? columnLabel(col) : colName}
      {op ? ` ${op}` : ""}: {shown}
      <button className="link" onClick={props.onClear} aria-label="Remove filter">
        ×
      </button>
    </span>
  );
}
