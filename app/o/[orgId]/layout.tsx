import { Suspense } from "react";
import { Shell } from "@/components/Shell";

export default function OrgLayout({ children }: { children: React.ReactNode }) {
  return (
    <Shell>
      <Suspense fallback={<div className="page muted">Loading…</div>}>{children}</Suspense>
    </Shell>
  );
}
