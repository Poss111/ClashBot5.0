#!/usr/bin/env bash
set -euo pipefail

# Spin up the local mock REST and WS services and run Flutter against them.
# This wraps run_mock.sh so you can start everything with one command.
#
# Defaults:
#   ENV=dev, mock REST on :4000 at /api/dev, mock WS on :4001 at /events/dev,
#   Flutter device = chrome
#
# Examples:
#   ./scripts/dev_mock_stack.sh
#   ./scripts/dev_mock_stack.sh -d macos
#   ./scripts/dev_mock_stack.sh --env prod --api-port 4100 --ws-port 4101
#   ./scripts/dev_mock_stack.sh -- --web-renderer html   # extra flutter args

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOCK_DIR="${ROOT_DIR}/mock-api"

ENV="${ENV:-dev}"
API_PORT="${MOCK_API_PORT:-4000}"
WS_PORT="${MOCK_WS_PORT:-4001}"
SKIP_FLUTTER=0
RUN_ARGS=()
ANDROID_DEVICE="${ANDROID_DEVICE:-emulator-5554}"
USE_ANDROID=0
HOST="${MOCK_HOST:-}"
HOST_PROVIDED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="$2"; shift 2;;
    --api-port) API_PORT="$2"; shift 2;;
    --ws-port) WS_PORT="$2"; shift 2;;
    -a|--android) USE_ANDROID=1; shift;;
    --host) HOST="$2"; HOST_PROVIDED=1; shift 2;;
    --no-flutter) SKIP_FLUTTER=1; shift;;
    --) shift; RUN_ARGS+=("$@"); break;;
    *) RUN_ARGS+=("$1"); shift;;
  esac
done

if [[ -n "${HOST}" ]]; then
  HOST_PROVIDED=1
fi

# Drop any accidental empty args to avoid passing a blank target to Flutter.
CLEAN_ARGS=()
for arg in "${RUN_ARGS[@]-}"; do
  if [[ -n "${arg:-}" ]]; then
    CLEAN_ARGS+=("$arg")
  fi
done
RUN_ARGS=("${CLEAN_ARGS[@]-}")

# Default host selection: if caller didn't supply, choose based on platform.
if [[ -z "${HOST}" ]]; then
  if [[ ${USE_ANDROID} -eq 1 ]]; then
    HOST="10.0.2.2"
  else
    HOST="localhost"
  fi
fi

if [[ ${USE_ANDROID} -eq 1 ]]; then
  # Android emulators need the host network via 10.0.2.2 by default when host not provided.
  if [[ ${HOST_PROVIDED} -eq 0 ]]; then
    HOST="10.0.2.2"
  fi
  # Prepend so user-supplied args still apply after the device selection.
  RUN_ARGS=("-d" "${ANDROID_DEVICE}" "${RUN_ARGS[@]-}")
fi

if [[ ! -d "${MOCK_DIR}/node_modules" ]]; then
  echo "Installing mock API dependencies in ${MOCK_DIR}..."
  (cd "${MOCK_DIR}" && npm install)
fi

API_PID=""
WS_PID=""
cleanup() {
  if [[ -n "${API_PID}" ]]; then kill "${API_PID}" 2>/dev/null || true; fi
  if [[ -n "${WS_PID}" ]]; then kill "${WS_PID}" 2>/dev/null || true; fi
}
trap cleanup EXIT INT TERM

echo "Starting mock REST on http://localhost:${API_PORT}/api/${ENV}"
(cd "${MOCK_DIR}" && PORT="${API_PORT}" API_PREFIX="/api" STAGE="/${ENV}" node server.js) &
API_PID=$!

echo "Starting mock WS on ws://localhost:${WS_PORT}/events/${ENV}"
(cd "${MOCK_DIR}" && PORT="${WS_PORT}" WS_PATH="/events/${ENV}" node websocket_server.js) &
WS_PID=$!

if [[ ${SKIP_FLUTTER} -eq 0 ]]; then
  # Add a default device if the caller did not supply one.
  NEED_DEVICE=true
  for arg in "${RUN_ARGS[@]-}"; do
    if [[ "$arg" == "-d" || "$arg" == "--device" ]]; then
      NEED_DEVICE=false
      break
    fi
  done
  if $NEED_DEVICE; then
    RUN_ARGS+=("-d" "chrome")
  fi

  echo "Running Flutter against local mocks (APP_ENV=${ENV})..."
  FLUTTER_ARGS=("${RUN_ARGS[@]-}")
  RUN_MOCK_NO_EXEC=1 "${ROOT_DIR}/scripts/run_mock.sh" \
    --env "${ENV}" \
    --host "${HOST}" \
    --api-port "${API_PORT}" \
    --ws-port "${WS_PORT}" \
    "${FLUTTER_ARGS[@]}"
else
  echo "Mock services are up; skipping Flutter because --no-flutter was set."
  echo "REST: http://localhost:${API_PORT}/api/${ENV}"
  echo "WS:   ws://localhost:${WS_PORT}/events/${ENV}"
  wait
fi
