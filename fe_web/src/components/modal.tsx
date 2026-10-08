"use client";

import { useEffect, useRef, type ReactNode } from "react";

export function Modal({ children, labelledBy, onClose, busy = false }: { children: ReactNode; labelledBy: string; onClose: () => void; busy?: boolean }) {
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => { const element = dialog.current; element?.showModal(); return () => element?.close(); }, []);
  return <dialog ref={dialog} className="module-dialog" aria-labelledby={labelledBy} onCancel={(event) => { event.preventDefault(); if (!busy) onClose(); }}>{children}</dialog>;
}
