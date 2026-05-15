#!/bin/bash
# Start OpenCode + openportal mobile UI + Dev Home PWA, accessible over Tailscale.
#
# Security: openportal connects to OpenCode on localhost — no password needed
# there. Tailscale provides network-level access control (only your tailnet
# can reach port 3000/4096). The Keychain password is preserved for direct
# `opencode serve` usage without openportal.
#
# Prerequisites:
#   1. Tailscale must be running and authenticated (open the menu bar app or run `tailscale up`)
#   2. Run this script from inside the project directory you want to work on.
#
# Access from phone (requires Tailscale connected on phone):
#   - Dev Home PWA:       http://<tailscale-ip>:8080  ← start here
#   - Mobile UI:          http://<tailscale-ip>:3000
#   - OpenCode API/UI:    http://<tailscale-ip>:4096
#   - Plannotator UI:     http://<tailscale-ip>:19432

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PWA_DIR="${SCRIPT_DIR}/../pwa"

# Ensure Homebrew binaries are on PATH (needed when script is launched outside a login shell)
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true

# openportal proxies to OpenCode on localhost — password would break it since
# openportal's SDK client sends no auth headers. Tailscale secures the network.
unset OPENCODE_SERVER_PASSWORD OPENCODE_SERVER_USERNAME

# Plannotator remote mode — fixed port so Tailscale access is stable
export PLANNOTATOR_REMOTE=1
export PLANNOTATOR_PORT=19432

TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "<tailscale-ip>")
echo "Starting dev services..."
echo "  Dev Home PWA:    http://${TAILSCALE_IP}:8080  ← open this on your phone"
echo "  Mobile UI:       http://${TAILSCALE_IP}:3000"
echo "  OpenCode:        http://${TAILSCALE_IP}:4096"
echo "  Plannotator UI:  http://${TAILSCALE_IP}:${PLANNOTATOR_PORT}"
echo ""
echo "Press Ctrl-C to stop all."
echo ""

# Clean up any stale openportal instances that might be holding ports
bunx openportal stop 2>/dev/null || true
bunx openportal clean 2>/dev/null || true

# Start Dev Home PWA server in background
bun run "${PWA_DIR}/server.ts" &
PWA_PID=$!

# Start openportal (manages opencode server internally)
bunx openportal --port 3000 --opencode-port 4096 --hostname 0.0.0.0 --directory "$(pwd)" --name "$(basename "$(pwd)")" &
PORTAL_PID=$!

trap 'echo ""; echo "Shutting down..."; kill $PWA_PID $PORTAL_PID 2>/dev/null; wait' EXIT INT TERM

wait $PWA_PID $PORTAL_PID

