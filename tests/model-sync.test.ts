// db/model.py is the source of truth: the generated files and the baseline must match it.
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, it } from "vitest";

const db = path.join(__dirname, "..", "db");
const read = (p: string) => readFileSync(path.join(db, p), "utf8");

it("generated schema matches db/model.py and the baseline migration", () => {
  const before = read("generated/schema.sql");
  try {
    execFileSync("python3", ["gen.py"], { cwd: db, stdio: "pipe" });
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code === "ENOENT") return; // no python: CI runs this check
    throw e;
  }
  const after = read("generated/schema.sql");
  expect(after, "db/generated is stale: run `npm run db:gen` and commit").toBe(before);
  expect(read("migrations/0001_baseline.sql"), "0001_baseline.sql differs from the generated schema").toBe(after);
});
