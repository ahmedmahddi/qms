import { useQuery } from "@tanstack/react-query";
import { Link, useParams } from "react-router-dom";
import { api, qs } from "../api";
import { humanize } from "../labels";
import { useCurrentOrg } from "../session";
import type { Page } from "../types";

const today = () => new Date().toISOString().slice(0, 10);

type Tile = { label: string; table: string; filter: Record<string, string>; tone?: "warn" | "bad" };

const TILES: Tile[] = [
  { label: "Open nonconformities", table: "nonconformities", filter: { status__in: "open,analysis,action_planned,in_progress,verification" } },
  { label: "Major NCs open", table: "nonconformities", filter: { severity: "major", status__ne: "closed" }, tone: "bad" },
  { label: "Open actions", table: "actions", filter: { status__in: "planned,in_progress" } },
  { label: "Overdue actions", table: "actions", filter: { status__in: "planned,in_progress", due_on__lt: today() }, tone: "warn" },
  { label: "Documents in review", table: "documents", filter: { status: "in_review" } },
  { label: "Processes", table: "processes", filter: { is_active: "true" } },
];

function useCount(orgId: string, table: string, filter: Record<string, string>) {
  return useQuery({
    queryKey: ["count", orgId, table, filter],
    queryFn: () => api<Page>(`/orgs/${orgId}/t/${table}${qs({ ...filter, limit: 1 })}`).then((p) => p.total),
  });
}

function KpiTile({ orgId, tile }: { orgId: string; tile: Tile }) {
  const { data, isLoading } = useCount(orgId, tile.table, tile.filter);
  const tone = data && tile.tone ? tile.tone : "";
  return (
    <Link className={`tile ${tone}`} to={`/o/${orgId}/${tile.table}${qs(tile.filter)}`}>
      <span className="tile-value">{isLoading ? "…" : data}</span>
      <span className="tile-label">{tile.label}</span>
    </Link>
  );
}

export function Home() {
  const { orgId = "" } = useParams();
  const org = useCurrentOrg();
  const activity = useQuery({
    queryKey: ["activity", orgId],
    queryFn: () => api<Page>(`/t/activity_log${qs({ org_id: orgId, order: "-occurred_at", limit: 12 })}`),
  });
  if (!org) return null;
  return (
    <div className="page">
      <div className="page-head">
        <div>
          <h1>{org.name}</h1>
          <p className="muted">
            {org.firm_name} · {org.is_member ? "member" : "consulting firm"} ·{" "}
            {org.firm_access === "full" ? "firm has full access" : `firm access: ${org.firm_access.replace("_", " ")}`}
          </p>
        </div>
      </div>
      <section className="tiles">
        {TILES.map((t) => (
          <KpiTile key={t.label} orgId={orgId} tile={t} />
        ))}
      </section>
      <section className="card">
        <h2>Recent activity</h2>
        {activity.data?.items.length ? (
          <ul className="activity">
            {activity.data.items.map((a) => (
              <li key={String(a.id)}>
                <span className={`badge b-${a.action}`}>{String(a.action)}</span>{" "}
                {a.entity_id && a.action !== "delete" ? (
                  <Link to={`/o/${orgId}/${a.entity_type}/${a.entity_id}`}>{humanize(String(a.entity_type))}</Link>
                ) : (
                  humanize(String(a.entity_type))
                )}
                <span className="muted"> · {new Date(String(a.occurred_at)).toLocaleString()}</span>
              </li>
            ))}
          </ul>
        ) : (
          <p className="muted">No changes recorded yet.</p>
        )}
      </section>
    </div>
  );
}
