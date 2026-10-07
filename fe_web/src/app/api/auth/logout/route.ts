import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { apiRequest } from "@/lib/api";
import { AUTH_COOKIE_NAME } from "@/lib/auth-constants";
import { hasTrustedOrigin } from "@/lib/request-security";

export async function POST(request: Request) {
  if (!hasTrustedOrigin(request)) {
    return NextResponse.json(
      { success: false, message: "Origin permintaan tidak diizinkan." },
      { status: 403 },
    );
  }

  const cookieStore = await cookies();
  const token = cookieStore.get(AUTH_COOKIE_NAME)?.value;

  if (token) {
    await apiRequest("/logout", { method: "POST", cache: "no-store" }, token).catch(
      () => null,
    );
  }

  const response = NextResponse.json({ success: true, message: "Logout berhasil." });
  response.cookies.set(AUTH_COOKIE_NAME, "", {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 0,
  });
  return response;
}
