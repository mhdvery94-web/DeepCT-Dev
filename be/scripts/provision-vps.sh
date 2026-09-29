#!/usr/bin/env bash
#
# One-time provisioning for the VPS that runs the backend.
#
# The deploy job in .github/workflows/release.yml deliberately does none of
# this. It never writes `.env`, never seeds, and never touches nginx, because a
# deploy that owned those would overwrite production credentials on the next
# push. Somebody has to set them up once instead, and this is that somebody.
#
# It lives under be/ on purpose: the deploy rsyncs `be/` and nothing else, so a
# script anywhere above that would never reach the server that needs it. On the
# server it lands at $APP_DIR/scripts/provision-vps.sh.
#
# Run it on the server, from the application directory, as the account the
# deploy will use:
#
#   cd /var/www/deepct-ai
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
PHP_BIN="${PHP_BIN:-$(command -v php)}"
SERVER_NAME="${SERVER_NAME:-api.brin.fajrianhost.my.id}"
APP_URL="${APP_URL:-https://$SERVER_NAME}"  # only written into a *new* .env

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
NGINX_BODY_LIMIT="${NGINX_BODY_LIMIT:-100M}"
PHP_MEMORY_LIMIT="${PHP_MEMORY_LIMIT:-512M}"

# Passed straight through to deploy/apply.sh, which owns nginx and supervisor.
#
# The assumption not to make is that this machine serves only us. It may
# already carry an unrelated site on 80 and 443, in which case this backend
# belongs on ports of its own — which is why these default to 8080 and 8443
# rather than 80 and 443.
#
# TLS_DOMAIN empty means the plain-HTTP door only. Set it to a hostname this
# machine already holds a certificate for; the certificate binds the hostname,
# not the port, so an existing one works on a port of our own without any new
# DNS record.
HTTP_PORT="${HTTP_PORT:-8080}"
TLS_PORT="${TLS_PORT:-8443}"
TLS_DOMAIN="${TLS_DOMAIN:-}"

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

# Composer has to run before the first Artisan command. On an update `vendor/`
# already exists and this is cheap; on a new server `key:generate` cannot even
# bootstrap until `vendor/autoload.php` has been installed.
say "PHP dependencies"

composer install --no-dev --optimize-autoloader --no-interaction --no-progress

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
  # No CORS note here on purpose. config/cors.php has never been published, so
  # the framework default applies and allowed_origins is `*` — which is safe
  # here because Sanctum is used with bearer tokens and nothing sends a cookie.
  # See ARCHITECTURE section 8.
fi

# The file contains the application key, database password and worker token.
# It must not inherit the world-readable mode from .env.example.
chmod 600 .env

# ---------------------------------------------------------------- RoadRunner

say "RoadRunner"

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
php artisan config:cache
php artisan route:cache
php artisan view:cache

if [ -n "${SEED_ADMIN_PASSWORD:-}" ]; then
  SEED_ADMIN_EMAIL="${SEED_ADMIN_EMAIL:-admin@brin.go.id}" \
  SEED_ADMIN_PASSWORD="$SEED_ADMIN_PASSWORD" \
    php artisan db:seed --force
  echo "    seeded the first administrator as ${SEED_ADMIN_EMAIL:-admin@brin.go.id}."
else
  warn "SEED_ADMIN_PASSWORD not set, so no administrator was created."
  warn "Run: SEED_ADMIN_PASSWORD='...' php artisan db:seed --force"
fi

# The directories Laravel needs at run time. They exist in the repository as
# folders holding nothing but a .gitignore, and the deploy excludes `storage/`
# wholesale, so they can only ever arrive here. Missing, they produce "Please
# provide a valid cache path" on every request — a 500 that is routinely
# misread as a missing view.
mkdir -p   storage/app/private   storage/app/public   storage/framework/cache/data   storage/framework/sessions   storage/framework/testing   storage/framework/views   storage/logs   storage/backups
chmod -R ug+rwX storage bootstrap/cache

# ------------------------------------------------- nginx, supervisor, proof
#
# Delegated rather than duplicated. `deploy/apply.sh` writes both configuration
# files from the templates beside it and then proves the result answers, and it
# is the file that ships with every deploy — so a change to a timeout or an
# upload limit lands on the server without anybody remembering this script
# exists.
#
# It also does the two things this script used to get wrong on a machine that
# already carried other work: it replaces the site that already proxies to this
# backend instead of adding a second one, and it replaces the file that already
# defines [program:brin-octane] instead of adding a second definition. Two
# files defining the same program make supervisorctl refuse to reread anything
# at all, which surfaces later as the deploy job reporting that supervisor does
# not know the programs it is looking at.

say "nginx and supervisor"

[ -x "$APP_DIR/deploy/apply.sh" ] || [ -f "$APP_DIR/deploy/apply.sh" ]   || die "$APP_DIR/deploy/apply.sh is missing. It arrives with a deploy; run one first."

APP_DIR="$APP_DIR" RUN_USER="$SERVICE_USER" PHP_BIN="$PHP_BIN" HTTP_PORT="${HTTP_PORT:-8080}" TLS_PORT="${TLS_PORT:-8443}" TLS_DOMAIN="${TLS_DOMAIN:-}" BODY_LIMIT="${NGINX_BODY_LIMIT:-100M}"   bash "$APP_DIR/deploy/apply.sh"


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
