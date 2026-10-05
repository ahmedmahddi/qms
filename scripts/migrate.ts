import { migrate } from "../lib/server/migrate";

migrate().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
