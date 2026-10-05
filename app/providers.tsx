"use client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";

export function Providers({ children }: { children: React.ReactNode }) {
  const [client] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          // Retry network/5xx hiccups, never 4xx answers (forbidden, not found, validation).
          queries: { retry: (n, e) => n < 2 && !(e && "status" in e && Number(e.status) < 500) },
        },
      }),
  );
  return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
}
