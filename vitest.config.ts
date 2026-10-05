import path from "node:path";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: { alias: { "@": path.resolve(__dirname) } },
  test: {
    globalSetup: ["tests/global-setup.ts"],
    setupFiles: ["tests/env.ts"],
    fileParallelism: false,
    testTimeout: 20_000,
  },
});
