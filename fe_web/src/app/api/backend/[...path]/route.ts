import { cookies } from "next/headers";
import { NextResponse, type NextRequest } from "next/server";
import { apiUrl } from "@/lib/api";
import { AUTH_COOKIE_NAME } from "@/lib/auth-constants";
import { hasTrustedOrigin } from "@/lib/request-security";

const METHODS_WITHOUT_BODY = new Set(["GET", "HEAD"]);
const MUTATING_METHODS = new Set(["POST", "PUT", "PATCH", "DELETE"]);
const REQUEST_HEADERS = [
  "accept",
  "content-type",
  "range",
  "if-none-match",
  "if-modified-since",
  "content-range",
];
const RESPONSE_HEADERS = [
  "accept-ranges",
  "cache-control",
  "content-disposition",
  "content-length",
  "content-range",
  "content-type",
  "etag",
  "last-modified",
];

function buildPath(segments: string[]): string {
  return `/${segments.map((segment) => encodeURIComponent(segment)).join("/")}`;
}

async function handler(
  request: NextRequest,
  context: { params: Promise<{ path: string[] }> },
) {
  if (MUTATING_METHODS.has(request.method) && !hasTrustedOrigin(request)) {
    return NextResponse.json(
      { success: false, message: "Origin permintaan tidak diizinkan." },
      { status: 403 },
    );
  }

  const { path } = await context.params;
  const target = new URL(apiUrl(buildPath(path)));
  target.search = request.nextUrl.search;

  const headers = new Headers();
  for (const name of REQUEST_HEADERS) {
    const value = request.headers.get(name);
    if (value) headers.set(name, value);
  }

  const token = (await cookies()).get(AUTH_COOKIE_NAME)?.value;
  if (token) headers.set("authorization", `Bearer ${token}`);

  const init: RequestInit & { duplex?: "half" } = {
    method: request.method,
    headers,
    cache: "no-store",
    redirect: "manual",
  };

  if (!METHODS_WITHOUT_BODY.has(request.method)) {
    init.body = request.body;
    init.duplex = "half";
  }

  try {
    const upstream = await fetch(target, init);
    const responseHeaders = new Headers();
    for (const name of RESPONSE_HEADERS) {
      const value = upstream.headers.get(name);
      if (value) responseHeaders.set(name, value);
    }

    return new Response(upstream.body, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers: responseHeaders,
    });
  } catch {
    return NextResponse.json(
      { success: false, message: "Laravel API sedang tidak dapat dihubungi." },
      { status: 502 },
    );
  }
}

export const GET = handler;
export const POST = handler;
export const PUT = handler;
export const PATCH = handler;
export const DELETE = handler;
export const HEAD = handler;
