#!/usr/bin/env bash
set -euo pipefail

# Helper to run Flutter against the local mock REST/WS services.
# Defaults assume:
#   REST mock at http://localhost:4000/api/dev (API_PREFIX=/api, STAGE=/dev)
#   WS mock  at  ws://localhost:4001/events/dev
# Override ports/env via flags or env vars.
#
# Usage examples:
#   ./scripts/run_mock.sh -d chrome
#   ./scripts/run_mock.sh --env dev --api-port 4000 --ws-port 4001 -d macos
#   MOCK_API_PORT=5000 MOCK_WS_PORT=5001 ./scripts/run_mock.sh -d macos
#
# Pass through extra flutter run args after a -- separator:
#   ./scripts/run_mock.sh -d chrome -- --web-renderer html

ENV="${ENV:-dev}"
API_PORT="${MOCK_API_PORT:-4000}"
WS_PORT="${MOCK_WS_PORT:-4001}"
DEVICE=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV="$2"; shift 2;;
    --api-port)
      API_PORT="$2"; shift 2;;
    --ws-port)
      WS_PORT="$2"; shift 2;;
    -d|--device)
      DEVICE="$2"; shift 2;;
    --)
      shift
      EXTRA_ARGS+=("$@")
      break;;
    *)
      EXTRA_ARGS+=("$1"); shift;;
  esac
done

ORIGIN="http://localhost:${API_PORT}"
WS_ORIGIN="ws://localhost:${WS_PORT}"

CMD=(flutter run
  --dart-define=APP_ENV="${ENV}"
  --dart-define=CLOUDFRONT_ORIGIN="${ORIGIN}"
  --dart-define=CLOUDFRONT_WS_ORIGIN="${WS_ORIGIN}"
  --dart-define=MOCK_API_ORIGIN="${ORIGIN}"
  --dart-define=MOCK_WS_ORIGIN="${WS_ORIGIN}"
  --dart-define=MOCK_AUTH=true
  --dart-define=MOCK_TOKEN=mock-jwt-token
  --dart-define=MOCK_ROLE=GENERAL_USER
)

if [[ -n "${DEVICE}" ]]; then
  CMD+=(-d "${DEVICE}")
fi

if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  CMD+=("${EXTRA_ARGS[@]}")
fi

echo "+ ${CMD[*]}"
exec "${CMD[@]}"

