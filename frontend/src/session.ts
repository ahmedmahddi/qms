import { useQuery } from "@tanstack/react-query";
import { useParams } from "react-router-dom";
import { api } from "./api";
import type { Me, Meta, TableMeta } from "./types";

export function useMe() {
  return useQuery({ queryKey: ["me"], queryFn: () => api<Me>("/me"), staleTime: 60_000 });
}

export function useMeta() {
  return useQuery({ queryKey: ["meta"], queryFn: () => api<Meta>("/meta"), staleTime: Infinity });
}

export function useTable(name: string | undefined): TableMeta | undefined {
  const { data } = useMeta();
  return data?.tables.find((t) => t.name === name);
}

export function useCurrentOrg() {
  const { orgId } = useParams();
  const { data } = useMe();
  return data?.organizations.find((o) => o.id === orgId);
}
