import { NextResponse, type NextRequest } from "next/server";

// Cheap gate for the app pages: no session cookie → login. The API verifies the token itself.
export function middleware(req: NextRequest) {
  if (!req.cookies.has("qms_session")) return NextResponse.redirect(new URL("/login", req.url));
  return NextResponse.next();
}

export const config = { matcher: ["/", "/o/:path*"] };
