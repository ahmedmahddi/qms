"use client";
import { useQuery } from "@tanstack/react-query";
import { api, tablePath } from "@/lib/client/api";
import { useMeta } from "@/lib/client/session";
import type { Page } from "@/lib/types";

export type Option = { id: string; label: string };

/** Up to 500 rows of a table as {id, label}, for selects and for showing FK values. */
export function useOptions(table: string | null, orgId: string) {
  const { data: meta } = useMeta();
  const t = meta?.tables.find((x) => x.name === table);
  return useQuery({
    queryKey: ["options", table, t?.tenant ? orgId : null],
    enabled: !!t && !t.link,
    staleTime: 30_000,
    queryFn: async (): Promise<Option[]> => {
      const page = await api<Page>(`${tablePath(t!, orgId)}?limit=500`);
      return page.items.map((r) => ({ id: String(r.id), label: String(r._label ?? r.id) }));
    },
  });
}

export function useLabelOf(table: string | null, orgId: string) {
  const { data } = useOptions(table, orgId);
  const map = new Map((data ?? []).map((o) => [o.id, o.label]));
  return (id: unknown) => (id == null ? "" : (map.get(String(id)) ?? String(id).slice(0, 8) + "…"));
}
