#!/usr/bin/env bash
set -euo pipefail

# Build helper for Flutter (web, android apk, macOS desktop).
# Accepts CLI flags or environment variables; CLI wins.
# Usage examples:
#   ./scripts/build_all.sh --env prod --cf-origin https://dxxxx.cloudfront.net --cf-ws-origin wss://dxxxx.cloudfront.net
#   ENV=prod CF_ORIGIN=https://dxxxx.cloudfront.net CF_WS_ORIGIN=wss://dxxxx.cloudfront.net ./scripts/build_all.sh
# Options/env:
#   --env, ENV                : dev|prod (default: prod)
#   --cf-origin, CF_ORIGIN    : CloudFront HTTPS origin for REST (optional; recommended mobile/desktop)
#   --cf-ws-origin, CF_WS_ORIGIN : CloudFront WSS origin for WebSocket (optional; recommended mobile/desktop)
#   --skip-web, SKIP_WEB          : skip web build if set/non-empty
#   --skip-android, SKIP_ANDROID  : skip Android build if set/non-empty
#   --skip-macos, SKIP_MACOS      : skip macOS build if set/non-empty

ENV="${ENV:-prod}"
CF_ORIGIN="${CF_ORIGIN:-}"
CF_WS_ORIGIN="${CF_WS_ORIGIN:-}"
SKIP_WEB="${SKIP_WEB:-}"
SKIP_ANDROID="${SKIP_ANDROID:-}"
SKIP_MACOS="${SKIP_MACOS:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV="$2"; shift 2;;
    --cf-origin)
      CF_ORIGIN="$2"; shift 2;;
    --cf-ws-origin)
      CF_WS_ORIGIN="$2"; shift 2;;
    --skip-web)
      SKIP_WEB=1; shift;;
    --skip-android)
      SKIP_ANDROID=1; shift;;
    --skip-macos)
      SKIP_MACOS=1; shift;;
    *)
      echo "Unknown option: $1" >&2; exit 1;;
  esac
done

DART_DEFINES=(
  "--dart-define=APP_ENV=${ENV}"
)

if [[ -n "${CF_ORIGIN}" ]]; then
  DART_DEFINES+=("--dart-define=CLOUDFRONT_ORIGIN=${CF_ORIGIN}")
fi

if [[ -n "${CF_WS_ORIGIN}" ]]; then
  DART_DEFINES+=("--dart-define=CLOUDFRONT_WS_ORIGIN=${CF_WS_ORIGIN}")
fi

run() {
  echo "+ $*"
  "$@"
}

if [[ -z "${SKIP_WEB}" ]]; then
  run flutter build web --release "${DART_DEFINES[@]}"
fi

if [[ -z "${SKIP_ANDROID}" ]]; then
  run flutter build apk --release "${DART_DEFINES[@]}"
fi

if [[ -z "${SKIP_MACOS}" ]]; then
  run flutter build macos --release "${DART_DEFINES[@]}"
fi

