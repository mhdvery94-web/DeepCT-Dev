import test from "node:test";
import assert from "node:assert/strict";
import { hasTrustedOrigin } from "../src/lib/request-security.ts";

test("same-origin requests use the public host behind a Next proxy", () => {
  const request = new Request("http://localhost:3000/api/backend/access-requests", {
    headers: { host: "127.0.0.1:3000", origin: "http://127.0.0.1:3000" },
  });
  assert.equal(hasTrustedOrigin(request), true);
});
test("HTTPS public origins use the proxy scheme", () => {
  const request = new Request("http://localhost/api/auth/login", {
    headers: { host: "deepct-web.vercel.app", origin: "https://deepct-web.vercel.app", "x-forwarded-proto": "https" },
  });
  assert.equal(hasTrustedOrigin(request), true);
});
test("foreign origins, including a forged forwarded host, are rejected", () => {
  const request = new Request("https://deepct-web.vercel.app/api/backend/admin/users", {
    headers: { host: "deepct-web.vercel.app", origin: "https://attacker.example", "x-forwarded-host": "attacker.example" },
  });
  assert.equal(hasTrustedOrigin(request), false);
});
test("a protocol mismatch is rejected", () => {
  assert.equal(hasTrustedOrigin(new Request("https://deepct-web.vercel.app/api/auth/login", { headers: { origin: "http://deepct-web.vercel.app" } })), false);
});
test("opaque or malformed origins are rejected", () => {
  assert.equal(hasTrustedOrigin(new Request("https://deepct-web.vercel.app/api/auth/login", { headers: { origin: "null" } })), false);
});
