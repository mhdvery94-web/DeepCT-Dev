"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";
import { UiIcon } from "@/components/ui-icon";

export function RefreshButton() {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  return <button className="dashboard-refresh" type="button" disabled={pending} onClick={() => startTransition(() => router.refresh())}><UiIcon name="refresh" size={16} />{pending ? "Refreshing…" : "Refresh"}</button>;
}
