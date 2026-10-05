import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // pg is a Node-only driver; keep it out of the bundle and load it at runtime.
  serverExternalPackages: ["pg"],
};

export default nextConfig;
