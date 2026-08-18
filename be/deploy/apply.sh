#!/usr/bin/env bash
#
# Install the nginx site and the supervisor programs from the templates beside
# this file, then reload and prove the result answers.
#
# Separate from provision-vps.sh on purpose. That script runs once on a bare
# machine and does irreversible things — creates a database, writes an .env
# holding APP_KEY. This one only rewrites the two configuration files, is safe
# to run whenever they change, and arrives on the server with every deploy
# because it lives under be/.
#
#   cd /var/www/deepct-ai
#   TLS_DOMAIN=example.org bash deploy/apply.sh
#
# Leave TLS_DOMAIN unset and only the plain-HTTP door is written.
#
# It replaces rather than duplicates: it finds the file that already defines
# these programs, or already proxies to this backend, and writes there. A
# second file defining [program:brin-octane] makes supervisor refuse to reread
# at all, and a second server block on the same port is a silent duplicate that
# splits future edits between two files.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_DIR="${APP_DIR:-$(cd "$HERE/.." && pwd)}"
RUN_USER="${RUN_USER:-$(whoami)}"
PHP_BIN="${PHP_BIN:-$(command -v php)}"

HTTP_PORT="${HTTP_PORT:-8080}"
TLS_PORT="${TLS_PORT:-8443}"
TLS_DOMAIN="${TLS_DOMAIN:-}"
TLS_CERT="${TLS_CERT:-/etc/letsencrypt/live/$TLS_DOMAIN/fullchain.pem}"
TLS_KEY="${TLS_KEY:-/etc/letsencrypt/live/$TLS_DOMAIN/privkey.pem}"
BODY_LIMIT="${BODY_LIMIT:-100M}"

# The ngrok tunnel. Empty means no tunnel program is installed at all.
#
# NGROK_UPSTREAM points at nginx rather than at Octane: nginx holds the upload
# limit, the timeouts and the buffering settings, and a tunnel straight to 8000
# would bypass all three without saying so.
NGROK_DOMAIN="${NGROK_DOMAIN:-}"
NGROK_UPSTREAM="${NGROK_UPSTREAM:-$HTTP_PORT}"
NGROK_BIN="${NGROK_BIN:-$(command -v ngrok || true)}"
RUN_HOME="${RUN_HOME:-$(getent passwd "$RUN_USER" | cut -d: -f6)}"

say()  { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
warn() { printf '\033[33m    ! %s\033[0m\n' "$1"; }
die()  { printf '\033[31m    x %s\033[0m\n' "$1" >&2; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
command -v nginx >/dev/null || die "nginx is not installed."
command -v supervisorctl >/dev/null || die "supervisor is not installed."
sudo -n true 2>/dev/null || die "This account cannot use sudo without a password."
[ -n "$PHP_BIN" ] || die "No php on PATH."

fill() {
  sed -e "s|__APP_DIR__|$APP_DIR|g" \
      -e "s|__RUN_USER__|$RUN_USER|g" \
      -e "s|__PHP_BIN__|$PHP_BIN|g" \
      -e "s|__HTTP_PORT__|$HTTP_PORT|g" \
      -e "s|__TLS_PORT__|$TLS_PORT|g" \
      -e "s|__TLS_DOMAIN__|$TLS_DOMAIN|g" \
      -e "s|__TLS_CERT__|$TLS_CERT|g" \
      -e "s|__TLS_KEY__|$TLS_KEY|g" \
      -e "s|__BODY_LIMIT__|$BODY_LIMIT|g" \
      -e "s|__NGROK_BIN__|$NGROK_BIN|g" \
      -e "s|__NGROK_DOMAIN__|$NGROK_DOMAIN|g" \
      -e "s|__NGROK_UPSTREAM__|$NGROK_UPSTREAM|g" \
      -e "s|__RUN_HOME__|$RUN_HOME|g" \
      "$1"
}

# ------------------------------------------------------------------- nginx

say "nginx"

# `-R`, not `-r`: everything in sites-enabled is a symlink into
# sites-available, and GNU grep's `-r` follows symlinks only when they are
# named on the command line. With `-r` this finds nothing on any machine that
# enables its sites the normal way, and we would write a duplicate.
SITE="$(sudo -n grep -Rls "127\.0\.0\.1:8000" /etc/nginx/sites-enabled/ 2>/dev/null | head -1 || true)"
if [ -n "$SITE" ]; then
  SITE="$(readlink -f "$SITE")"
  echo "    replacing the site that already proxies here: $SITE"
else
  SITE="/etc/nginx/sites-available/${NGINX_SITE:-deepct}"
  echo "    no existing site found; writing $SITE"
fi

BACKUP=""
if [ -f "$SITE" ]; then
  BACKUP="$SITE.bak-$STAMP"
  sudo -n cp "$SITE" "$BACKUP"
  echo "    backup: $BACKUP"
fi

sudo -n install -d /etc/nginx/snippets
sudo -n cp "$HERE/nginx/deepct-proxy.conf" /etc/nginx/snippets/deepct-proxy.conf

TMP="$(mktemp)"
fill "$HERE/nginx/deepct-http.conf.template" > "$TMP"

if [ -n "$TLS_DOMAIN" ]; then
  [ -f "$TLS_CERT" ] || die "TLS_DOMAIN is set but $TLS_CERT does not exist."
  [ -f "$TLS_KEY" ]  || die "TLS_DOMAIN is set but $TLS_KEY does not exist."
  fill "$HERE/nginx/deepct-tls.conf.template" >> "$TMP"
  echo "    TLS: $TLS_DOMAIN on port $TLS_PORT, certificate $TLS_CERT"
else
  warn "TLS_DOMAIN not set. Writing the plain-HTTP door only."
  warn "A browser will refuse to call http:// from the HTTPS web client."
fi

sudo -n cp "$TMP" "$SITE"
rm -f "$TMP"
sudo -n ln -sf "$SITE" "/etc/nginx/sites-enabled/$(basename "$SITE")"

if sudo -n nginx -t; then
  sudo -n systemctl reload nginx
  echo "    reloaded."
else
  if [ -n "$BACKUP" ]; then
    warn "nginx -t failed. Restoring $BACKUP and reloading the old configuration."
    sudo -n cp "$BACKUP" "$SITE"
    sudo -n nginx -t && sudo -n systemctl reload nginx
  fi
  die "nginx rejected the generated configuration. Nothing was changed."
fi

# -------------------------------------------------------------- supervisor

say "supervisor"

# The same duplicate problem, with a worse failure mode: two files defining
# [program:brin-octane] make supervisorctl refuse to reread anything at all,
# so the next deploy cannot restart the application and says only that
# supervisor does not know the programs.
CONF="$(sudo -n grep -Rls '^\[program:brin-octane\]' /etc/supervisor/conf.d/ 2>/dev/null | head -1 || true)"
if [ -n "$CONF" ]; then
  echo "    replacing the file that already defines these programs: $CONF"
  sudo -n cp "$CONF" "$CONF.bak-$STAMP"
  echo "    backup: $CONF.bak-$STAMP"
else
  CONF="/etc/supervisor/conf.d/deepct.conf"
  echo "    no existing definition found; writing $CONF"
fi

TMP="$(mktemp)"
fill "$HERE/supervisor/deepct.conf.template" > "$TMP"

if [ -n "$NGROK_DOMAIN" ]; then
  [ -n "$NGROK_BIN" ] || die "NGROK_DOMAIN is set but no ngrok binary is on PATH."
  [ -n "$RUN_HOME" ] && [ -d "$RUN_HOME" ] \
    || die "No home directory for $RUN_USER; ngrok needs one to find its authtoken."
  [ -f "$RUN_HOME/.config/ngrok/ngrok.yml" ] \
    || warn "$RUN_HOME/.config/ngrok/ngrok.yml missing. Run: ngrok config add-authtoken <token>"
  echo "" >> "$TMP"
  fill "$HERE/supervisor/ngrok.conf.template" >> "$TMP"
  echo "    tunnel: $NGROK_DOMAIN -> localhost:$NGROK_UPSTREAM, via $NGROK_BIN"
fi

sudo -n cp "$TMP" "$CONF"
rm -f "$TMP"

sudo -n supervisorctl reread
sudo -n supervisorctl update
PROGRAMS="brin-octane brin-queue brin-schedule"
[ -n "$NGROK_DOMAIN" ] && PROGRAMS="$PROGRAMS brin-ngrok"
for program in $PROGRAMS; do
  sudo -n supervisorctl restart "$program" >/dev/null 2>&1 \
    || sudo -n supervisorctl start "$program" >/dev/null 2>&1 \
    || warn "could not start $program"
done
sudo -n supervisorctl status | sed 's/^/    /'

# ------------------------------------------------------------------- proof

say "Checking it answers"

# Asking the application, not asking systemd whether it started something.
# /api/news is public, cheap, reaches the database, and answers 200 on an
# empty feed, which is what makes it usable here.
for attempt in $(seq 1 10); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$HTTP_PORT/api/news" || true)"
  if [ "$code" = "200" ]; then
    echo "    http://127.0.0.1:$HTTP_PORT/api/news -> 200 after $attempt attempt(s)."
    break
  fi
  echo "    attempt $attempt: got '$code', waiting."
  sleep 3
  [ "$attempt" = "10" ] && die "The API never answered 200 on port $HTTP_PORT."
done

if [ -n "$NGROK_DOMAIN" ]; then
  # The tunnel takes a moment to register with ngrok's edge after a restart, so
  # the first attempt failing means nothing.
  for attempt in $(seq 1 10); do
    code="$(curl -s -o /dev/null -w '%{http_code}' \
      -H 'ngrok-skip-browser-warning: true' \
      "https://$NGROK_DOMAIN/api/news" --max-time 20 || true)"
    [ "$code" = "200" ] && break
    sleep 3
  done
  if [ "$code" = "200" ]; then
    echo "    https://$NGROK_DOMAIN/api/news -> 200 through the tunnel."
  else
    warn "https://$NGROK_DOMAIN/api/news answered '$code'."
    warn "Check: sudo supervisorctl status brin-ngrok; tail /var/log/brin-ngrok.err.log"
  fi
fi

if [ -n "$TLS_DOMAIN" ]; then
  code="$(curl -s -o /dev/null -w '%{http_code}' "https://$TLS_DOMAIN:$TLS_PORT/api/news" --max-time 20 || true)"
  if [ "$code" = "200" ]; then
    echo "    https://$TLS_DOMAIN:$TLS_PORT/api/news -> 200, certificate accepted."
  else
    warn "https://$TLS_DOMAIN:$TLS_PORT/api/news answered '$code'."
    warn "nginx is listening; if this timed out, port $TLS_PORT is closed in the"
    warn "cloud firewall or security group. That is outside this machine."
  fi
fi

say "Done."
