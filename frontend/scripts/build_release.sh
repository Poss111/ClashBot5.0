#!/usr/bin/env bash
set -euo pipefail

# Build release artifacts for web and Android with no mock flags.
# Defaults to APP_ENV=prod. Optionally supply CloudFront origins for mobile/desktop.
# Usage:
#   ./scripts/build_release.sh
#   ./scripts/build_release.sh --cf-origin https://dxxxx.cloudfront.net --cf-ws-origin wss://dxxxx.cloudfront.net
#   ./scripts/build_release.sh --web-only
#   ./scripts/build_release.sh --android-only
#
# Outputs:
#   Web:     build/web/
#   Android: build/app/outputs/bundle/release/app-release.aab
#            build/app/outputs/flutter-apk/app-release.apk

ENV="${ENV:-prod}"
CF_ORIGIN="${CF_ORIGIN:-}"
CF_WS_ORIGIN="${CF_WS_ORIGIN:-}"
WEB_ONLY="${WEB_ONLY:-}"
ANDROID_ONLY="${ANDROID_ONLY:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="$2"; shift 2;;
    --cf-origin) CF_ORIGIN="$2"; shift 2;;
    --cf-ws-origin) CF_WS_ORIGIN="$2"; shift 2;;
    --web-only) WEB_ONLY=1; shift;;
    --android-only) ANDROID_ONLY=1; shift;;
    *) echo "Unknown option: $1" >&2; exit 1;;
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

if [[ -z "${ANDROID_ONLY}" ]]; then
  run flutter build web --release "${DART_DEFINES[@]}"
fi

if [[ -z "${WEB_ONLY}" ]]; then
  run flutter build appbundle --release "${DART_DEFINES[@]}"
  run flutter build apk --release "${DART_DEFINES[@]}"
fi

