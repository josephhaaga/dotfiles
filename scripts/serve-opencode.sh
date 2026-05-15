#!/bin/bash
# Start OpenCode + openportal mobile UI + Dev Home PWA, accessible over Tailscale.
#
# Ports are chosen automatically by openportal to avoid conflicts — run this
# script from multiple project directories simultaneously without issues.
# The Dev Home PWA reads ~/.portal.json to discover all running instances.
#
# Prerequisites:
#   1. Tailscale must be running and authenticated
#   2. Run from inside the project directory you want to work on.
#
# Access from phone: http://<tailscale-ip>:8080  (Dev Home lists everything)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PWA_DIR="${SCRIPT_DIR}/../pwa"
PROJECT_NAME="$(basename "$(pwd)")"

# Ensure Homebrew binaries are on PATH
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true

# openportal proxies to OpenCode on localhost — Tailscale secures the network.
unset OPENCODE_SERVER_PASSWORD OPENCODE_SERVER_USERNAME

# Plannotator remote mode — fixed port so Tailscale access is stable
export PLANNOTATOR_REMOTE=1
export PLANNOTATOR_PORT=19432

TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "<tailscale-ip>")

# Clean up stale openportal entries for this directory only
bunx openportal stop --name "${PROJECT_NAME}" 2>/dev/null || true
bunx openportal clean 2>/dev/null || true

# Start openportal with auto-selected ports (no --port / --opencode-port)
# so multiple instances in different dirs can run simultaneously
bunx openportal --hostname 0.0.0.0 --directory "$(pwd)" --name "${PROJECT_NAME}" &
PORTAL_PID=$!

# Give openportal a moment to register its chosen ports in ~/.portal.json
sleep 2

# Start Dev Home PWA (only once — skip if already running)
if ! lsof -iTCP:8080 -sTCP:LISTEN &>/dev/null; then
  bun run "${PWA_DIR}/server.ts" &
  PWA_PID=$!
  echo "  Dev Home PWA:  http://${TAILSCALE_IP}:8080  ← open this on your phone"
else
  PWA_PID=""
  echo "  Dev Home PWA:  http://${TAILSCALE_IP}:8080  (already running)"
fi

echo "  Project:       ${PROJECT_NAME}"
echo "  Plannotator:   http://${TAILSCALE_IP}:${PLANNOTATOR_PORT}"
echo "  (OpenPortal + OpenCode ports auto-assigned — see Dev Home)"
echo ""
echo "Press Ctrl-C to stop."
echo ""

if [[ -n "${PWA_PID}" ]]; then
  trap 'echo ""; echo "Shutting down..."; kill $PWA_PID $PORTAL_PID 2>/dev/null; wait' EXIT INT TERM
  wait $PWA_PID $PORTAL_PID
else
  trap 'echo ""; echo "Shutting down..."; kill $PORTAL_PID 2>/dev/null; wait' EXIT INT TERM
  wait $PORTAL_PID
fi

