/**
 * Runs before `next build` on Vercel (the "vercel-build" script).
 *   QMS_MIGRATE_ON_BUILD=true   apply pending migrations
 *   QMS_SEED_DEMO=true          load the demo data, only into an empty database
 * Both are opt-in so a build never touches a database you did not mean it to.
 */
import { migrate, seed } from "../lib/server/migrate";

async function main() {
  if (!process.env.DATABASE_URL) {
    console.log("deploy-db: DATABASE_URL not set, skipping");
    return;
  }
  if (process.env.QMS_MIGRATE_ON_BUILD === "true") await migrate();
  else console.log("deploy-db: QMS_MIGRATE_ON_BUILD is not true, skipping migrations");
  if (process.env.QMS_SEED_DEMO === "true") console.log((await seed("dev", undefined, true)) ? "deploy-db: demo data loaded" : "deploy-db: database not empty, demo seed skipped");
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
