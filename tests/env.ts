// Runs in every test worker before the tests import anything.
import { TEST_URL } from "./global-setup";

process.env.DATABASE_URL = TEST_URL;
process.env.QMS_DEV_AUTH = "true";
process.env.QMS_JWT_SECRET = "test-secret-" + "x".repeat(32);
