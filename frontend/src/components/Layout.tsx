import { useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { NavLink, Outlet, useNavigate, useParams } from "react-router-dom";
import { setToken } from "../api";
import { humanize, isPrimary } from "../labels";
import { useCurrentOrg, useMe, useMeta } from "../session";

export function Layout() {
  const { orgId = "" } = useParams();
  const { data: me } = useMe();
  const { data: meta } = useMeta();
  const org = useCurrentOrg();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [showAll, setShowAll] = useState(false);
  const [filter, setFilter] = useState("");

  if (!me || !meta) return <div className="center muted">Loading…</div>;
  if (!org) return <div className="center">You do not have access to this organization.</div>;

  const visible = meta.tables.filter(
    (t) =>
      (showAll || isPrimary(meta, t)) &&
      (!filter || t.name.includes(filter.toLowerCase().replace(/ /g, "_"))),
  );

  return (
    <div className="shell">
      <header className="topbar">
        <NavLink to={`/o/${orgId}`} className="brand">
          QMS
        </NavLink>
        <select
          className="org-switch"
          value={orgId}
          onChange={(e) => navigate(`/o/${e.target.value}`)}
          aria-label="Organization"
        >
          {me.organizations.map((o) => (
            <option key={o.id} value={o.id}>
              {o.name}
              {o.type === "internal" ? " (internal)" : ""}
            </option>
          ))}
        </select>
        {!org.can_write ? <span className="badge b-read_only">read-only access</span> : null}
        <span className="spacer" />
        <span className="muted user">{me.user.full_name}</span>
        <button
          className="ghost"
          onClick={() => {
            setToken(null);
            qc.clear();
            navigate("/login");
          }}
        >
          Sign out
        </button>
      </header>
      <aside className="sidebar">
        <input className="nav-filter" placeholder="Find a register…" value={filter} onChange={(e) => setFilter(e.target.value)} />
        {Object.entries(meta.domains).map(([key, label]) => {
          const tables = visible.filter((t) => t.domain === key);
          if (!tables.length) return null;
          return (
            <details key={key} open={!!filter || key === "improvement" || key === "documents"}>
              <summary>{label}</summary>
              {tables.map((t) => (
                <NavLink key={t.name} to={`/o/${orgId}/${t.name}`} className="nav-item" title={t.desc}>
                  {humanize(t.name)}
                  {!t.tenant ? <span className="tag">lib</span> : null}
                </NavLink>
              ))}
            </details>
          );
        })}
        <label className="show-all muted">
          <input type="checkbox" checked={showAll} onChange={(e) => setShowAll(e.target.checked)} /> Show all{" "}
          {meta.stats.tables} tables
        </label>
      </aside>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
