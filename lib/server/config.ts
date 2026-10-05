const DEV_SECRET = "dev-only-secret-change-me-0123456789abcdef";

export const config = {
  get databaseUrl() {
    return process.env.DATABASE_URL ?? "postgresql://qms_owner:qms@localhost:5432/qms";
  },
  /** Password-less login with the demo accounts (local testing and throwaway demos only). */
  get devAuth() {
    return process.env.QMS_DEV_AUTH === "true";
  },
  get jwtSecret(): Uint8Array {
    const s = process.env.QMS_JWT_SECRET || (this.devAuth ? DEV_SECRET : "");
    if (!s) throw new Error("QMS_JWT_SECRET must be set when QMS_DEV_AUTH is not true");
    return new TextEncoder().encode(s);
  },
  jwtTtlSeconds: 60 * 60 * 12,
  sessionCookie: "qms_session",
};
