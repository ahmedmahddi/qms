import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { getToken } from "./api";
import { Layout } from "./components/Layout";
import { Home } from "./pages/Home";
import { Login } from "./pages/Login";
import { RecordPage } from "./pages/RecordPage";
import { TableList } from "./pages/TableList";
import { useMe } from "./session";
import "./styles.css";

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: (n, e) => n < 2 && !(e && "status" in e && Number(e.status) < 500) } },
});

function RequireAuth({ children }: { children: React.ReactElement }) {
  return getToken() ? children : <Navigate to="/login" replace />;
}

function Landing() {
  const { data } = useMe();
  if (!data) return <div className="center muted">Loading…</div>;
  const first = data.organizations.find((o) => o.type !== "internal") ?? data.organizations[0];
  return first ? <Navigate to={`/o/${first.id}`} replace /> : <div className="center">No organization yet.</div>;
}

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/" element={<RequireAuth><Landing /></RequireAuth>} />
          <Route path="/o/:orgId" element={<RequireAuth><Layout /></RequireAuth>}>
            <Route index element={<Home />} />
            <Route path=":table" element={<TableList />} />
            <Route path=":table/:id" element={<RecordPage />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  </React.StrictMode>,
);
