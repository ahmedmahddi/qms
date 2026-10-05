"use client";
import { useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useState } from "react";
import { api } from "@/lib/client/api";
import { humanize, isPrimary } from "@/lib/client/labels";
import { useCurrentOrg, useMe, useMeta, useOrgId } from "@/lib/client/session";

export function Shell({ children }: { children: React.ReactNode }) {
  const orgId = useOrgId();
  const pathname = usePathname();
  const { data: me } = useMe();
  const { data: meta } = useMeta();
  const org = useCurrentOrg();
  const router = useRouter();
  const qc = useQueryClient();
  const [showAll, setShowAll] = useState(false);
  const [filter, setFilter] = useState("");

  if (!me || !meta) return <div className="center muted">Loading…</div>;
  if (!org) return <div className="center">You do not have access to this organization.</div>;

  const visible = meta.tables.filter(
    (t) => (showAll || isPrimary(meta, t)) && (!filter || t.name.includes(filter.toLowerCase().replace(/ /g, "_"))),
  );

  async function signOut() {
    await api("/auth/logout", { method: "POST" });
    qc.clear();
    router.push("/login");
  }

  return (
    <div className="shell">
      <header className="topbar">
        <Link href={`/o/${orgId}`} className="brand">
          QMS
        </Link>
        <select className="org-switch" value={orgId} onChange={(e) => router.push(`/o/${e.target.value}`)} aria-label="Organization">
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
        <button className="ghost" onClick={() => void signOut()}>
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
              {tables.map((t) => {
                const href = `/o/${orgId}/${t.name}`;
                const active = pathname === href || pathname.startsWith(`${href}/`);
                return (
                  <Link key={t.name} href={href} className={`nav-item ${active ? "active" : ""}`} title={t.desc}>
                    {humanize(t.name)}
                    {!t.tenant ? <span className="tag">lib</span> : null}
                  </Link>
                );
              })}
            </details>
          );
        })}
        <label className="show-all muted">
          <input type="checkbox" checked={showAll} onChange={(e) => setShowAll(e.target.checked)} /> Show all {meta.stats.tables} tables
        </label>
      </aside>
      <main className="content">{children}</main>
    </div>
  );
}
