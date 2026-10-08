import "server-only";

import { cache } from "react";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { AUTH_COOKIE_NAME } from "@/lib/auth-constants";
import type { ApiEnvelope, DeepCtUser, NewsPost, UserStats } from "@/lib/types";

type NextRequestInit = RequestInit & {
  next?: { revalidate?: number; tags?: string[] };
};

const LOCAL_API = "http://127.0.0.1:8000/api";

export class ApiError extends Error {
  constructor(
    message: string,
    public readonly status: number,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

export function apiBaseUrl(): string {
  const configured =
    process.env.LARAVEL_API_BASE_URL ??
    process.env.RASPI_API_BASE_URL ??
    process.env.NGROK_RASPI ??
    (process.env.NODE_ENV === "production" ? "" : LOCAL_API);

  if (!configured.trim()) throw new Error("LARAVEL_API_BASE_URL must point to the Raspberry Pi API.");
  const base = configured.trim().replace(/\/+$/, "");
  return base.endsWith("/api") ? base : `${base}/api`;
}

export function apiUrl(path: string): string {
  if (!path.startsWith("/") || path.startsWith("//")) {
    throw new Error("API path must be an absolute path without a host.");
  }

  return `${apiBaseUrl()}${path}`;
}

export function firstApiMessage(payload: unknown, fallback: string): string {
  if (!payload || typeof payload !== "object") return fallback;

  const response = payload as {
    message?: unknown;
    errors?: Record<string, unknown>;
  };

  if (typeof response.message === "string" && response.message.trim()) {
    return response.message;
  }

  if (response.errors && typeof response.errors === "object") {
    for (const value of Object.values(response.errors)) {
      if (Array.isArray(value) && typeof value[0] === "string") {
        return value[0];
      }
    }
  }

  return fallback;
}

export async function apiRequest<T>(
  path: string,
  init: NextRequestInit = {},
  token?: string,
): Promise<T> {
  const headers = new Headers(init.headers);
  headers.set("Accept", "application/json");
  headers.set("ngrok-skip-browser-warning", "true");
  if (token) headers.set("Authorization", `Bearer ${token}`);

  const response = await fetch(apiUrl(path), {
    ...init,
    headers,
  });

  const payload: unknown = await response.json().catch(() => null);
  if (!response.ok) {
    throw new ApiError(
      firstApiMessage(payload, "Laravel API tidak dapat memproses permintaan."),
      response.status,
    );
  }

  return payload as T;
}

export async function getPublishedNews(): Promise<NewsPost[]> {
  try {
    const response = await apiRequest<ApiEnvelope<NewsPost[]>>("/news?limit=20", {
      next: { revalidate: 60, tags: ["research-news"] },
    });
    return Array.isArray(response.data) ? response.data : [];
  } catch (error) {
    // The landing page must still render during a backend restart or a build.
    console.error(
      "Unable to load published research news:",
      error instanceof Error ? error.message : "unknown error",
    );
    return [];
  }
}

export const getCurrentUser = cache(async (): Promise<DeepCtUser | null> => {
  const token = (await cookies()).get(AUTH_COOKIE_NAME)?.value;
  if (!token) return null;

  try {
    const response = await apiRequest<ApiEnvelope<DeepCtUser>>(
      "/user",
      { cache: "no-store" },
      token,
    );
    return response.data;
  } catch (error) {
    if (error instanceof ApiError && [401, 403].includes(error.status)) {
      return null;
    }
    throw error;
  }
});

export async function requireUser(): Promise<DeepCtUser> {
  const user = await getCurrentUser();
  if (!user) redirect("/login");
  return user;
}

export async function requireAdmin(): Promise<DeepCtUser> {
  const user = await requireUser();
  if (user.role !== "admin") redirect("/dashboard");
  return user;
}

export async function getUserStats(role: "admin" | "user" = "user"): Promise<UserStats | null> {
  const token = (await cookies()).get(AUTH_COOKIE_NAME)?.value;
  if (!token) return null;

  try {
    const response = await apiRequest<ApiEnvelope<UserStats>>(
      role === "admin" ? "/admin/stats" : "/me/stats",
      { cache: "no-store" },
      token,
    );
    return response.data;
  } catch {
    return null;
  }
}
