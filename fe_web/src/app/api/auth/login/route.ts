import { NextResponse } from "next/server";
import { apiRequest, ApiError } from "@/lib/api";
import { AUTH_COOKIE_NAME, AUTH_MAX_AGE_SECONDS } from "@/lib/auth-constants";
import { hasTrustedOrigin } from "@/lib/request-security";
import type { ApiEnvelope, DeepCtUser } from "@/lib/types";

type LoginPayload = ApiEnvelope<{ user: DeepCtUser; token: string }>;

export async function POST(request: Request) {
  if (!hasTrustedOrigin(request)) {
    return NextResponse.json(
      { success: false, message: "Origin permintaan tidak diizinkan." },
      { status: 403 },
    );
  }

  if (!request.headers.get("content-type")?.includes("application/json")) {
    return NextResponse.json(
      { success: false, message: "Gunakan content type application/json." },
      { status: 415 },
    );
  }

  const body: unknown = await request.json().catch(() => null);
  if (!body || typeof body !== "object") {
    return NextResponse.json(
      { success: false, message: "Data login tidak valid." },
      { status: 400 },
    );
  }

  const { email, password } = body as Record<string, unknown>;
  if (typeof email !== "string" || typeof password !== "string") {
    return NextResponse.json(
      { success: false, message: "Email dan password wajib diisi." },
      { status: 422 },
    );
  }

  try {
    const payload = await apiRequest<LoginPayload>("/login", {
      method: "POST",
      cache: "no-store",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: email.trim(), password }),
    });

    const response = NextResponse.json({
      success: true,
      message: payload.message ?? "Login berhasil.",
      data: { user: payload.data.user },
    });

    response.cookies.set(AUTH_COOKIE_NAME, payload.data.token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      path: "/",
      maxAge: AUTH_MAX_AGE_SECONDS,
      priority: "high",
    });

    return response;
  } catch (error) {
    const status = error instanceof ApiError ? error.status : 502;
    const message =
      error instanceof ApiError
        ? error.message
        : "Server autentikasi sedang tidak dapat dihubungi.";

    return NextResponse.json({ success: false, message }, { status });
  }
}
