import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { FormEvent, useEffect, useMemo, useState } from "react";
import { Link, useNavigate, useParams, useSearchParams } from "react-router-dom";
import { api, ApiError, qs, tablePath } from "../api";
import { Field } from "../components/Field";
import { columnLabel, humanize } from "../labels";
import { useCurrentOrg, useMeta, useTable } from "../session";
import type { Column, Page, Row, TableMeta } from "../types";

const SERVER = new Set(["id", "organization_id", "created_at", "updated_at", "created_by"]);
const HUBS = new Set(["organizations", "users", "firms", "files", "firm_members", "org_memberships"]);

export function RecordPage() {
  const { orgId = "", table: name, id = "new" } = useParams();
  const table = useTable(name);
  if (!table) return null;
  return <Record key={`${table.name}/${id}`} orgId={orgId} table={table} id={id} />;
}

function Record({ orgId, table, id }: { orgId: string; table: TableMeta; id: string }) {
  const isNew = id === "new";
  const [search] = useSearchParams();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const org = useCurrentOrg();
  const base = tablePath(table, orgId);
  const fields = table.columns.filter((c) => !SERVER.has(c.name));
  const readOnly = !table.writable || (table.tenant && !org?.can_write);

  const record = useQuery({ queryKey: ["record", base, id], enabled: !isNew, queryFn: () => api<Row>(`${base}/${id}`) });

  const initial = useMemo<Row>(() => {
    if (!isNew) return record.data ?? {};
    // Prefill from the list's filters (e.g. "New" from an NC's related actions sets nonconformity_id).
    const prefill: Row = {};
    for (const [k, v] of search) if (fields.some((c) => c.name === k)) prefill[k] = v;
    return prefill;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isNew, record.data]);

  const [values, setValues] = useState<Row>(initial);
  useEffect(() => setValues(initial), [initial]);

  const save = useMutation({
    mutationFn: async () => {
      const payload: Row = {};
      for (const c of fields) {
        const v = values[c.name];
        if (isNew ? v === undefined || v === null : !changed(initial[c.name], v)) continue;
        payload[c.name] = c.base_type === "jsonb" ? parseJson(c, v) : v;
      }
      return isNew
        ? api<Row>(base, { method: "POST", body: JSON.stringify(payload) })
        : api<Row>(`${base}/${id}`, { method: "PATCH", body: JSON.stringify(payload) });
    },
    onSuccess: (row) => {
      void qc.invalidateQueries({ queryKey: ["list", orgId, table.name] });
      void qc.invalidateQueries({ queryKey: ["options", table.name] });
      void qc.invalidateQueries({ queryKey: ["count"] });
      qc.setQueryData(["record", base, String(row.id)], row);
      if (isNew) navigate(table.link ? `/o/${orgId}/${table.name}` : `/o/${orgId}/${table.name}/${row.id}`, { replace: true });
    },
  });

  const remove = useMutation({
    mutationFn: () => api<void>(`${base}/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["list", orgId, table.name] });
      void qc.invalidateQueries({ queryKey: ["options", table.name] });
      navigate(`/o/${orgId}/${table.name}`, { replace: true });
    },
  });

  if (!isNew && record.isLoading) return <div className="page muted">Loading…</div>;
  if (!isNew && record.error) return <div className="page error">{(record.error as ApiError).detail}</div>;

  const err = (save.error ?? remove.error) as ApiError | null;
  const title = isNew ? `New ${humanize(table.name).toLowerCase()}` : String(record.data?._label ?? "");

  function onSubmit(e: FormEvent) {
    e.preventDefault();
    save.mutate();
  }

  return (
    <div className="page">
      <div className="page-head">
        <div>
          <Link to={`/o/${orgId}/${table.name}`} className="muted small">
            ← {humanize(table.name)}
          </Link>
          <h1>{title}</h1>
        </div>
        {!isNew && !readOnly && !table.link ? (
          <button
            className="danger ghost"
            onClick={() => confirm(`Delete "${title}"? This cannot be undone.`) && remove.mutate()}
          >
            Delete
          </button>
        ) : null}
      </div>
      <div className="record">
        <form className="card form" onSubmit={onSubmit}>
          {fields.map((c) => (
            <div key={c.name} className={`field ${err?.column === c.name ? "invalid" : ""} ${c.array && c.enum ? "wide" : ""}`}>
              <label htmlFor={`f-${c.name}`} title={c.comment || undefined}>
                {columnLabel(c)}
                {c.required ? <span className="req"> *</span> : null}
              </label>
              <Field col={c} value={values[c.name]} orgId={orgId} disabled={readOnly} onChange={(v) => setValues((s) => ({ ...s, [c.name]: v }))} />
              {c.comment ? <small className="muted">{c.comment}</small> : null}
            </div>
          ))}
          {err ? <p className="error wide">{err.detail}</p> : null}
          {!readOnly ? (
            <div className="actions wide">
              <button type="submit" disabled={save.isPending}>
                {save.isPending ? "Saving…" : isNew ? "Create" : "Save changes"}
              </button>
              {save.isSuccess && !isNew ? <span className="muted">Saved.</span> : null}
            </div>
          ) : (
            <p className="muted wide">Read-only.</p>
          )}
          {!isNew && record.data ? (
            <p className="muted small wide">
              Created {fmt(record.data.created_at)}
              {record.data.updated_at ? ` · updated ${fmt(record.data.updated_at)}` : ""}
            </p>
          ) : null}
        </form>
        {!isNew && !table.link ? (
          <aside className="side">
            <Related orgId={orgId} table={table} id={id} />
            {table.tenant ? <Comments orgId={orgId} entityType={table.name} entityId={id} /> : null}
          </aside>
        ) : null}
      </div>
    </div>
  );
}

function Related({ orgId, table, id }: { orgId: string; table: TableMeta; id: string }) {
  const { data: meta } = useMeta();
  if (!meta || HUBS.has(table.name)) return null;
  const children: [TableMeta, Column][] = [];
  for (const t of meta.tables)
    for (const c of t.columns) if (c.fk === table.name && !SERVER.has(c.name) && t.name !== table.name) children.push([t, c]);
  if (!children.length) return null;
  return (
    <section className="card">
      <h3>Related</h3>
      <ul className="related">
        {children.map(([t, c]) => (
          <RelatedItem key={`${t.name}.${c.name}`} orgId={orgId} child={t} col={c} id={id} multi={children.filter(([x]) => x === t).length > 1} />
        ))}
      </ul>
    </section>
  );
}

function RelatedItem({ orgId, child, col, id, multi }: { orgId: string; child: TableMeta; col: Column; id: string; multi: boolean }) {
  const { data } = useQuery({
    queryKey: ["count", orgId, child.name, { [col.name]: id }],
    queryFn: () => api<Page>(`${tablePath(child, orgId)}${qs({ [col.name]: id, limit: 1 })}`).then((p) => p.total),
  });
  return (
    <li>
      <Link to={`/o/${orgId}/${child.name}${qs({ [col.name]: id })}`}>
        {humanize(child.name)}
        {multi ? <span className="muted"> ({columnLabel(col).toLowerCase()})</span> : null}
      </Link>
      <span className={`count ${data ? "" : "zero"}`}>{data ?? "…"}</span>
    </li>
  );
}

function Comments({ orgId, entityType, entityId }: { orgId: string; entityType: string; entityId: string }) {
  const org = useCurrentOrg();
  const qc = useQueryClient();
  const [body, setBody] = useState("");
  const [internal, setInternal] = useState(false);
  const key = ["comments", orgId, entityId];
  const list = useQuery({
    queryKey: key,
    queryFn: () => api<Page>(`/orgs/${orgId}/t/comments${qs({ entity_type: entityType, entity_id: entityId, order: "created_at" })}`),
  });
  const post = useMutation({
    mutationFn: () =>
      api<Row>(`/orgs/${orgId}/t/comments`, {
        method: "POST",
        body: JSON.stringify({ entity_type: entityType, entity_id: entityId, body, visibility: internal ? "firm_internal" : "shared" }),
      }),
    onSuccess: () => {
      setBody("");
      void qc.invalidateQueries({ queryKey: key });
    },
  });
  return (
    <section className="card">
      <h3>Comments</h3>
      {list.data?.items.map((c) => (
        <div key={String(c.id)} className={`comment ${c.visibility === "firm_internal" ? "internal" : ""}`}>
          <p>{String(c.body)}</p>
          <small className="muted">
            {fmt(c.created_at)}
            {c.visibility === "firm_internal" ? " · firm only" : ""}
          </small>
        </div>
      ))}
      {org?.can_write ? (
        <form
          onSubmit={(e) => {
            e.preventDefault();
            if (body.trim()) post.mutate();
          }}
        >
          <textarea rows={2} value={body} onChange={(e) => setBody(e.target.value)} placeholder="Add a comment…" />
          <div className="actions">
            {org.is_firm_side ? (
              <label className="small">
                <input type="checkbox" checked={internal} onChange={(e) => setInternal(e.target.checked)} /> Firm only
              </label>
            ) : null}
            <button type="submit" disabled={!body.trim() || post.isPending}>
              Post
            </button>
          </div>
          {post.error ? <p className="error">{(post.error as ApiError).detail}</p> : null}
        </form>
      ) : null}
    </section>
  );
}

function changed(a: unknown, b: unknown): boolean {
  return JSON.stringify(a ?? null) !== JSON.stringify(b ?? null);
}

function parseJson(c: Column, v: unknown): unknown {
  if (typeof v !== "string") return v;
  try {
    return JSON.parse(v);
  } catch {
    throw new ApiError(400, `${columnLabel(c)}: invalid JSON`, c.name);
  }
}

function fmt(v: unknown): string {
  return v ? new Date(String(v)).toLocaleString() : "";
}
