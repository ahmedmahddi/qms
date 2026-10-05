/**
 * Tests run against a real, throwaway PostgreSQL database: RLS is the point.
 * QMS_TEST_ADMIN_URL: an owner connection to any database on the server (needs CREATEDB).
 */
import pg from "pg";
import { migrate, seed } from "../lib/server/migrate";

const ADMIN_URL = process.env.QMS_TEST_ADMIN_URL ?? "postgresql://qms_owner:qms@localhost:5432/postgres";
export const TEST_URL = ADMIN_URL.replace(/\/[^/?]+(\?.*)?$/, "/qms_test$1");

export default async function setup() {
  const admin = new pg.Client({ connectionString: ADMIN_URL });
  await admin.connect();
  await admin.query("DROP DATABASE IF EXISTS qms_test WITH (FORCE)");
  await admin.query("CREATE DATABASE qms_test");
  await admin.end();
  await migrate(TEST_URL, () => {});
  await seed("dev", TEST_URL);
}
