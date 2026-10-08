export function hasTrustedOrigin(request: Request): boolean {
  const origin = request.headers.get("origin");
  if (!origin) return true;

  try {
    const requestUrl = new URL(request.url);
    const originUrl = new URL(origin);
    // Next may construct request.url with the internal server hostname.
    // Browsers send the public Host; the proxy supplies the external scheme.
    const host = request.headers.get("host") ?? requestUrl.host;
    const forwardedProtocol = request.headers.get("x-forwarded-proto")?.split(",")[0].trim();
    const protocol = forwardedProtocol ? `${forwardedProtocol}:` : requestUrl.protocol;
    return originUrl.host === host && originUrl.protocol === protocol;
  } catch {
    return false;
  }
}
