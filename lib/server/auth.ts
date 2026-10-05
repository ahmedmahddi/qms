/**
 * Sessions are short JWTs issued by this app whose subject is users.id, carried in an httpOnly
 * cookie (or an Authorization: Bearer header for API clients). Today they come from the demo
 * login (QMS_DEV_AUTH=true); a real identity provider will mint the same token later.
 */
import { jwtVerify, SignJWT } from "jose";
import { config } from "./config";

export async function issueToken(userId: string): Promise<string> {
  return new SignJWT({})
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(userId)
    .setIssuedAt()
    .setExpirationTime(`${config.jwtTtlSeconds}s`)
    .sign(config.jwtSecret);
}

export async function userIdFrom(req: Request): Promise<string | null> {
  const header = req.headers.get("authorization");
  const cookie = req.headers.get("cookie")?.split(/;\s*/).find((c) => c.startsWith(`${config.sessionCookie}=`));
  const token = header?.startsWith("Bearer ") ? header.slice(7) : cookie?.slice(config.sessionCookie.length + 1);
  if (!token) return null;
  try {
    const { payload } = await jwtVerify(token, config.jwtSecret, { algorithms: ["HS256"] });
    return typeof payload.sub === "string" ? payload.sub : null;
  } catch {
    return null;
  }
}

export function sessionCookie(token: string | null, secure: boolean): string {
  const attrs = [`${config.sessionCookie}=${token ?? ""}`, "Path=/", "HttpOnly", "SameSite=Lax"];
  if (secure) attrs.push("Secure");
  attrs.push(`Max-Age=${token ? config.jwtTtlSeconds : 0}`);
  return attrs.join("; ");
}
