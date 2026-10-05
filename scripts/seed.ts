import { seed } from "../lib/server/migrate";

seed(process.argv[2] ?? "dev")
  .then(() => console.log("seeded"))
  .catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
