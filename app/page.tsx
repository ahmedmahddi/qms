"use client";
import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { useMe } from "@/lib/client/session";

export default function Landing() {
  const { data } = useMe();
  const router = useRouter();
  const first = data?.organizations.find((o) => o.type !== "internal") ?? data?.organizations[0];
  useEffect(() => {
    if (first) router.replace(`/o/${first.id}`);
  }, [first, router]);
  if (data && !first) return <div className="center">No organization yet.</div>;
  return <div className="center muted">Loading…</div>;
}
