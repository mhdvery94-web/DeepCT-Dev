#!/usr/bin/env bash
#
# Builds the Flutter web client on Vercel.
#
# Vercel has no Flutter preset and its build image has no Flutter SDK, so this
# script fetches one before building. It downloads the *released* tarball rather
# than cloning github.com/flutter/flutter: the tarball already contains the Dart
# SDK, which a fresh clone would otherwise download on first run, and it is a
# few hundred megabytes instead of a repository with full history.
#
# Two environment variables are read, both set in the Vercel project:
#
#   API_BASE_URL     where the compiled client looks for the backend. It is
#                    baked in at compile time (see lib/config/api_config.dart),
#                    so Production and Preview must set it separately — that is
#                    what makes one deployment production and the other testing.
#   FLUTTER_VERSION  optional; keep it in step with .github/workflows/release.yml
#                    so CI and Vercel compile the same client.
#
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.9}"
FLUTTER_HOME="/tmp/flutter"
API_BASE_URL="${API_BASE_URL:-https://nucleus-drone-grueling.ngrok-free.dev/api}"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  echo "▸ Fetching Flutter $FLUTTER_VERSION"
  curl -fsSL --retry 3 \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C /tmp
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
export PUB_CACHE="/tmp/.pub-cache"

# The SDK is owned by a different uid than the build runs as, and Flutter reads
# its version with git. Without this it aborts on "dubious ownership".
git config --global --add safe.directory "$FLUTTER_HOME"

flutter --version
flutter pub get

echo "▸ Building against API_BASE_URL=$API_BASE_URL"
flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL"
