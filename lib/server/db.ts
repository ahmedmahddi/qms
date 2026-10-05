/**
 * Connection pool and per-request transactions.
 *
 * Every request runs in one transaction that first switches to the qms_app role (no ownership,
 * no BYPASSRLS) and sets app.user_id, which the RLS policies read through app.current_user_id().
 * Nothing outside userTx / anonTx touches the database.
 */
import pg from "pg";
import { config } from "./config";

// Return dates and timestamps as ISO strings, like the JSON the client receives.
pg.types.setTypeParser(1082, (v) => v); // date
pg.types.setTypeParser(1184, (v) => new Date(v).toISOString()); // timestamptz
pg.types.setTypeParser(1114, (v) => v); // timestamp

export type Db = pg.PoolClient;

const g = globalThis as unknown as { qmsPool?: pg.Pool };

export function pool(): pg.Pool {
  // Kept on globalThis so dev hot-reloads and warm serverless invocations reuse it.
  g.qmsPool ??= new pg.Pool({ connectionString: config.databaseUrl, max: 5, idleTimeoutMillis: 10_000 });
  return g.qmsPool;
}

export async function closePool() {
  await g.qmsPool?.end();
  g.qmsPool = undefined;
}

export class InactiveUser extends Error {}

async function tx<T>(userId: string | null, fn: (db: Db) => Promise<T>): Promise<T> {
  const client = await pool().connect();
  try {
    await client.query("BEGIN");
    await client.query("SET LOCAL ROLE qms_app");
    await client.query("SELECT set_config('app.user_id', $1, true)", [userId ?? ""]);
    if (userId) {
      const { rows } = await client.query("SELECT status FROM users WHERE id = $1", [userId]);
      if (rows[0]?.status !== "active") throw new InactiveUser();
    }
    const result = await fn(client);
    await client.query("COMMIT");
    return result;
  } catch (e) {
    await client.query("ROLLBACK").catch(() => {});
    throw e;
  } finally {
    client.release();
  }
}

/** A transaction acting as `userId`: RLS policies see this user. */
export const userTx = <T>(userId: string, fn: (db: Db) => Promise<T>) => tx(userId, fn);

/** A transaction with no user: only the SECURITY DEFINER login helpers are useful here. */
export const anonTx = <T>(fn: (db: Db) => Promise<T>) => tx(null, fn);
