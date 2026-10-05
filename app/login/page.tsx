"use client";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { type FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { api, ApiError } from "@/lib/client/api";
import type { Me } from "@/lib/types";

const DEV_USERS = [
  ["owner@atlas.test", "Firm owner — every client"],
  ["consultant@atlas.test", "Consultant — assigned to Alpha"],
  ["qse@alpha.test", "Alpha — QSE manager"],
  ["gerant@alpha.test", "Alpha — top management"],
  ["qse@beta.test", "Beta — QSE manager (firm read-only)"],
];

export default function Login() {
  const [email, setEmail] = useState("");
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();
  const qc = useQueryClient();
  const { data: cfg } = useQuery({ queryKey: ["auth-config"], queryFn: () => api<{ dev_auth: boolean }>("/auth/config") });

  async function signIn(address: string) {
    setError(null);
    try {
      await api("/auth/dev-login", {
        method: "POST",
        body: JSON.stringify({ email: address }),
      });
      qc.clear();
      const me = await qc.fetchQuery({ queryKey: ["me"], queryFn: () => api<Me>("/me") });
      const first = me.organizations.find((o) => o.type !== "internal") ?? me.organizations[0];
      router.push(first ? `/o/${first.id}` : "/");
    } catch (e) {
      setError(e instanceof ApiError ? e.detail : String(e));
    }
  }

  function onSubmit(e: FormEvent) {
    e.preventDefault();
    void signIn(email);
  }

  return (
    <div className="login">
      <form className="card" onSubmit={onSubmit}>
        <h1>QMS</h1>
        <p className="muted">Quality, health &amp; safety and environment management</p>
        {cfg && !cfg.dev_auth ? (
          <p>Single sign-on is not configured yet. Set QMS_DEV_AUTH=true to use the demo accounts.</p>
        ) : (
          <>
            <label htmlFor="email">E-mail</label>
            <input id="email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoFocus />
            <button type="submit" disabled={!email}>
              Sign in
            </button>
            {error ? <p className="error">{error}</p> : null}
            <p className="muted small">Development accounts</p>
            <div className="dev-users">
              {DEV_USERS.map(([address, role]) => (
                <button type="button" key={address} className="ghost" onClick={() => void signIn(address)}>
                  <strong>{address}</strong>
                  <span className="muted">{role}</span>
                </button>
              ))}
            </div>
          </>
        )}
      </form>
    </div>
  );
}
