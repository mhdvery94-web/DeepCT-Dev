import type { Metadata } from "next";
import type { ReactNode } from "react";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000"),
  title: {
    default: "BRIN Neutron CT Platform",
    template: "%s | BRIN Neutron CT Platform",
  },
  description:
    "Secure deep-learning workflows for neutron and X-ray computed tomography research.",
  icons: { icon: "/assets/BRIN_Logo.ico" },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
