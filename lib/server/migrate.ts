/**
 * Apply db/migrations/*.sql in order, each in its own transaction, as the connecting (owner) role.
 * A migration that changed after being applied is refused: add a new one instead.
 */
import { createHash } from "node:crypto";
import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import pg from "pg";

const DB_DIR = path.join(process.cwd(), "db");

/** Migrations and seeds prefer a direct connection: Neon's pooled URL sits behind PgBouncer. */
export const ownerUrl = () =>
  process.env.DATABASE_URL_UNPOOLED ?? process.env.DATABASE_URL ?? "postgresql://qms_owner:qms@localhost:5432/qms";

export async function migrate(url = ownerUrl(), log: (m: string) => void = console.log): Promise<string[]> {
  const client = new pg.Client({ connectionString: url });
  await client.connect();
  const applied: string[] = [];
  try {
    await client.query(
      "CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, sha256 text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())",
    );
    const done = new Map<string, string>(
      (await client.query("SELECT name, sha256 FROM schema_migrations")).rows.map((r) => [r.name, r.sha256]),
    );
    const dir = path.join(DB_DIR, "migrations");
    for (const name of readdirSync(dir).filter((f) => f.endsWith(".sql")).sort()) {
      const body = readFileSync(path.join(dir, name), "utf8");
      const sha = createHash("sha256").update(body).digest("hex");
      if (done.has(name)) {
        if (done.get(name) !== sha) throw new Error(`${name} changed after being applied; add a new migration instead`);
        continue;
      }
      await client.query("BEGIN");
      try {
        await client.query(body);
        await client.query("INSERT INTO schema_migrations (name, sha256) VALUES ($1, $2)", [name, sha]);
        await client.query("COMMIT");
      } catch (e) {
        await client.query("ROLLBACK");
        throw new Error(`${name}: ${(e as Error).message}`);
      }
      applied.push(name);
      log(`applied ${name}`);
    }
    if (!applied.length) log("migrations up to date");
    return applied;
  } finally {
    await client.end();
  }
}

/** Load db/seed/<name>.sql. With `onlyIfEmpty`, skip when a firm already exists. */
export async function seed(name = "dev", url = ownerUrl(), onlyIfEmpty = false): Promise<boolean> {
  const client = new pg.Client({ connectionString: url });
  await client.connect();
  try {
    if (onlyIfEmpty && (await client.query("SELECT 1 FROM firms LIMIT 1")).rowCount) return false;
    await client.query(readFileSync(path.join(DB_DIR, "seed", `${name}.sql`), "utf8"));
    return true;
  } finally {
    await client.end();
  }
}
