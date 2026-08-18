#!/usr/bin/env bash
#
# One-time provisioning for the VPS that runs the backend.
#
# The deploy job in .github/workflows/release.yml deliberately does none of
# this. It never writes `.env`, never seeds, and never touches nginx, because a
# deploy that owned those would overwrite production credentials on the next
# push. Somebody has to set them up once instead, and this is that somebody.
#
# Run it on the server, as the account the deploy will use:
#
#   DB_PASSWORD='...' SEED_ADMIN_PASSWORD='...' bash scripts/provision-vps.sh
#
# It is safe to run again. Every step checks for what it is about to create,
# and the one thing it will never overwrite is an existing `.env` — that file
# holds the application key, and replacing it makes every encrypted value and
# every issued token unreadable.

set -euo pipefail

# ---------------------------------------------------------------- settings

APP_DIR="${APP_DIR:-/var/www/deepct-ai}"
SERVICE_USER="${SERVICE_USER:-$(whoami)}"
SERVER_NAME="${SERVER_NAME:-api.brin.fajrianhost.my.id}"
APP_URL="${APP_URL:-https://$SERVER_NAME}"

DB_DATABASE="${DB_DATABASE:-db_aict}"
DB_USERNAME="${DB_USERNAME:-aict}"
DB_PASSWORD="${DB_PASSWORD:-}"

# Upload sizing, and the reason all three numbers appear together.
#
# PredictionUploadController::chunkSize() derives the chunk it advertises from
# PHP's own `upload_max_filesize` and `post_max_size` at run time, so raising
# them here is what makes chunks bigger. nginx has to allow more than the
# largest chunk or it answers 413 before PHP ever sees the request — and
# Ubuntu's default `client_max_body_size` is 1m, which is smaller than the
# chunk PHP would advertise on a stock install. That mismatch is invisible
# until the first upload from a real client.
PHP_UPLOAD_LIMIT="${PHP_UPLOAD_LIMIT:-32M}"
NGINX_BODY_LIMIT="${NGINX_BODY_LIMIT:-64m}"
PHP_MEMORY_LIMIT="${PHP_MEMORY_LIMIT:-512M}"

say()  { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
warn() { printf '\033[33m    ! %s\033[0m\n' "$1"; }
die()  { printf '\033[31m    x %s\033[0m\n' "$1" >&2; exit 1; }

# ---------------------------------------------------------------- guards

say "Checking the machine"

[ -d "$APP_DIR" ] || die "$APP_DIR does not exist. Create it and put the code there first."
cd "$APP_DIR"
[ -f artisan ] || die "$APP_DIR has no artisan. This should be the contents of be/, not the repository root."

for tool in php composer mysql nginx supervisorctl curl; do
  command -v "$tool" >/dev/null || die "$tool is not installed."
done

sudo -n true 2>/dev/null || die "This account cannot use sudo without a password. The deploy job needs that too."

php -r 'exit(version_compare(PHP_VERSION, "8.2", ">=") ? 0 : 1);' \
  || die "PHP $(php -r 'echo PHP_VERSION;') is too old; composer.json wants 8.2 or newer."

echo "    $(php -v | head -1)"
echo "    user: $SERVICE_USER, dir: $APP_DIR, host: $SERVER_NAME"

# ---------------------------------------------------------------- php.ini
#
# The CLI php.ini, not the FPM one, and that is not a mistake: RoadRunner
# executes the application through the CLI SAPI. There is no PHP-FPM in this
# stack at all, so the FPM ini would be edited to no effect whatsoever.

say "PHP limits"

PHP_INI="$(php -i | awk -F'=> *' '/Loaded Configuration File/ {print $2}' | tr -d ' ')"
if [ -z "$PHP_INI" ] || [ ! -f "$PHP_INI" ]; then
  warn "No loaded php.ini found; skipping. Chunk sizes will follow the built-in defaults."
else
  set_ini() {
    if grep -qE "^\s*;?\s*$1\s*=" "$PHP_INI"; then
      sudo sed -i -E "s|^\s*;?\s*$1\s*=.*|$1 = $2|" "$PHP_INI"
    else
      echo "$1 = $2" | sudo tee -a "$PHP_INI" >/dev/null
    fi
    echo "    $1 = $2"
  }
  set_ini upload_max_filesize "$PHP_UPLOAD_LIMIT"
  set_ini post_max_size       "$PHP_UPLOAD_LIMIT"
  set_ini memory_limit        "$PHP_MEMORY_LIMIT"
  # config/octane.php documents this one as kept in sync with php.ini.
  set_ini max_execution_time  300
  echo "    ($PHP_INI)"
fi

# ---------------------------------------------------------------- database

say "Database"

if sudo mysql -N -e "SHOW DATABASES LIKE '$DB_DATABASE';" | grep -q "$DB_DATABASE"; then
  echo "    $DB_DATABASE already exists, left alone."
else
  [ -n "$DB_PASSWORD" ] || die "DB_PASSWORD is empty and the database has to be created. Set it and run again."
  sudo mysql <<SQL
CREATE DATABASE \`$DB_DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USERNAME'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DB_DATABASE\`.* TO '$DB_USERNAME'@'localhost';
FLUSH PRIVILEGES;
SQL
  echo "    created $DB_DATABASE and granted it to $DB_USERNAME."
fi

# ---------------------------------------------------------------- .env
#
# Never overwritten. APP_KEY lives here, and replacing it makes every
# encrypted column and every issued token unreadable — a failure that shows up
# as "everyone is logged out and nothing decrypts", nowhere near this script.

say "Configuration"

if [ -f .env ]; then
  echo "    .env exists, left exactly as it is."
else
  [ -n "$DB_PASSWORD" ] || die "DB_PASSWORD is empty and .env has to be written. Set it and run again."

  cp .env.example .env
  set_env() {
    if grep -qE "^\s*#?\s*$1=" .env; then
      sed -i -E "s|^\s*#?\s*$1=.*|$1=$2|" .env
    else
      echo "$1=$2" >> .env
    fi
  }
  set_env APP_ENV        production
  set_env APP_DEBUG      false
  set_env APP_URL        "$APP_URL"
  set_env LOG_LEVEL      warning
  set_env DB_CONNECTION  mysql
  set_env DB_HOST        127.0.0.1
  set_env DB_PORT        3306
  set_env DB_DATABASE    "$DB_DATABASE"
  set_env DB_USERNAME    "$DB_USERNAME"
  set_env DB_PASSWORD    "$DB_PASSWORD"
  set_env QUEUE_CONNECTION database
  set_env SESSION_DRIVER database
  set_env OCTANE_SERVER  roadrunner

  # A fresh token for production. ARCHITECTURE section 8 asks for one on the
  # grounds that the development token has been through terminals and logs.
  #
  # `openssl rand` rather than a /dev/urandom pipeline ending in `head`: under
  # `set -o pipefail`, `head` closing the pipe early can SIGPIPE the stage
  # feeding it and take the whole script down. It depends on buffer timing, so
  # it would pass in testing and fail on the machine that matters.
  set_env TRAINING_WORKER_TOKEN "$(openssl rand -hex 24)"

  php artisan key:generate --force
  echo "    wrote .env with APP_DEBUG=false and a fresh training worker token."
  warn "CORS: config/cors.php must allow the web client's origin. Check it."
fi

# ---------------------------------------------------------------- dependencies

say "Dependencies"

composer install --no-dev --optimize-autoloader --no-interaction --no-progress

# RoadRunner's binary is gitignored, so it is never in the deploy's rsync — and
# the deploy excludes `rr` explicitly so it is never deleted either. It has to
# arrive once, here.
if [ -x ./rr ]; then
  echo "    rr already present: $(./rr --version 2>&1 | head -1)"
else
  # Two ways, because which one works depends on the Octane version. The
  # second is what the first calls anyway.
  php artisan octane:install --server=roadrunner --no-interaction \
    || ./vendor/bin/rr get-binary --location . \
    || die "Could not fetch the RoadRunner binary. Without it octane:start cannot run."
  [ -x ./rr ] || die "The RoadRunner install reported success but there is no ./rr."
  echo "    installed $(./rr --version 2>&1 | head -1)"
fi

# ---------------------------------------------------------------- schema

say "Schema"

php artisan migrate --force

if [ -n "${SEED_ADMIN_PASSWORD:-}" ]; then
  SEED_ADMIN_EMAIL="${SEED_ADMIN_EMAIL:-admin@brin.go.id}" \
  SEED_ADMIN_PASSWORD="$SEED_ADMIN_PASSWORD" \
    php artisan db:seed --force
  echo "    seeded the first administrator as ${SEED_ADMIN_EMAIL:-admin@brin.go.id}."
else
  warn "SEED_ADMIN_PASSWORD not set, so no administrator was created."
  warn "Run: SEED_ADMIN_PASSWORD='...' php artisan db:seed --force"
fi

mkdir -p storage/backups
chmod -R ug+rwX storage bootstrap/cache

# ---------------------------------------------------------------- supervisor
#
# Three programs, because three processes have to be alive and none of them
# starts on its own. Without the queue worker an upload succeeds and the
# prediction sits at `pending` for ever; without the scheduler, expired files
# are never deleted and model status goes stale.
#
# The names are load-bearing: the deploy job restarts them by these exact
# names and stops with an error if supervisor does not know one.

say "Supervisor"

PHP_BIN="$(command -v php)"
sudo tee /etc/supervisor/conf.d/brin.conf >/dev/null <<CONF
; Written by scripts/provision-vps.sh. The deploy job restarts these three by
; name; renaming one means editing .github/workflows/release.yml to match.

[program:brin-octane]
command=$PHP_BIN artisan octane:start --server=roadrunner --host=127.0.0.1 --port=8000 --workers=4 --max-requests=250
directory=$APP_DIR
user=$SERVICE_USER
autostart=true
autorestart=true
; Octane needs longer than the default 10s to finish in-flight requests.
stopwaitsecs=30
stdout_logfile=/var/log/supervisor/brin-octane.log
redirect_stderr=true

[program:brin-queue]
; --tries=1 because an interpolation job is not safely repeatable, and 7200
; because a large sequence genuinely takes that long.
command=$PHP_BIN artisan queue:work --tries=1 --timeout=7200
directory=$APP_DIR
user=$SERVICE_USER
autostart=true
autorestart=true
; Longer than the job timeout, or supervisor kills a run that is still working.
stopwaitsecs=7260
stdout_logfile=/var/log/supervisor/brin-queue.log
redirect_stderr=true

[program:brin-schedule]
command=$PHP_BIN artisan schedule:work
directory=$APP_DIR
user=$SERVICE_USER
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/brin-schedule.log
redirect_stderr=true
CONF

sudo supervisorctl reread
sudo supervisorctl update
for program in brin-octane brin-queue brin-schedule; do
  sudo supervisorctl restart "$program" >/dev/null 2>&1 || sudo supervisorctl start "$program" || true
done
sudo supervisorctl status | sed 's/^/    /'

# ---------------------------------------------------------------- nginx

say "nginx"

sudo tee /etc/nginx/sites-available/brin-api >/dev/null <<CONF
# Written by scripts/provision-vps.sh.
#
# A reverse proxy and nothing more. Octane serves everything including static
# files, so there is no root and no try_files here — pointing nginx at public/
# as well would give two answers to the same request.

server {
    listen 80;
    listen [::]:80;
    server_name $SERVER_NAME;

    # Must exceed the largest chunk PHP will advertise. See the note in
    # provision-vps.sh about why these two numbers travel together.
    client_max_body_size $NGINX_BODY_LIMIT;

    # A prediction runs on the queue, not in the request, so these cover slow
    # uploads over a bad link rather than slow inference.
    proxy_connect_timeout 60s;
    proxy_send_timeout    600s;
    proxy_read_timeout    600s;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host              \$host;
        proxy_set_header X-Real-IP         \$remote_addr;
        proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade           \$http_upgrade;
        proxy_set_header Connection        "upgrade";
        # Results reach ~1.5 GB. Buffering one to disk before sending a byte
        # would double the wait and fill /var/lib/nginx.
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
CONF

sudo ln -sf /etc/nginx/sites-available/brin-api /etc/nginx/sites-enabled/brin-api
sudo nginx -t
sudo systemctl reload nginx
echo "    proxying $SERVER_NAME to 127.0.0.1:8000, body limit $NGINX_BODY_LIMIT."

# ---------------------------------------------------------------- proof
#
# Asking the application, rather than asking systemd whether it started
# something. /api/news is public, cheap, reaches the database, and answers 200
# on an empty feed, which is what makes it usable as a check.

say "Checking it actually answers"

ok=0
for attempt in $(seq 1 10); do
  code="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8000/api/news || true)"
  if [ "$code" = "200" ]; then
    echo "    GET /api/news -> 200 after $attempt attempt(s)."
    ok=1
    break
  fi
  echo "    attempt $attempt: got '$code', waiting."
  sleep 3
done

if [ "$ok" != "1" ]; then
  sudo supervisorctl status brin-octane || true
  tail -n 40 /var/log/supervisor/brin-octane.log 2>/dev/null || true
  die "The application never answered on 127.0.0.1:8000."
fi

# ---------------------------------------------------------------- what is left

say "Done. What this script did not do:"

cat <<'NEXT'
    1. TLS. Point the DNS at this machine first, then:
           sudo certbot --nginx -d <the hostname above>
       Until then the API is HTTP only, and a browser on an HTTPS page will
       refuse to call it.

    2. Off-machine backups. Deploys now dump the database before migrating and
       keep seven, but those seven sit on this disk, next to the database they
       are meant to survive.

    3. The inference endpoint. It is registered through Admin -> Model
       Management, not through .env.

    4. CORS. config/cors.php has to allow the web client's origin.
NEXT
