#!/bin/bash
# Start OpenCode as a server accessible over Tailscale, plus the openportal mobile UI.
#
# Prerequisites:
#   1. Tailscale must be running and authenticated (open the menu bar app or run `tailscale up`)
#   2. Set the server password in Keychain (one-time):
#        security add-generic-password -a "$USER" -s opencode-server -w 'your-password'
#   3. Run this script from inside the project directory you want to work on.
#
# Access from phone (both require Tailscale):
#   - Mobile UI (openportal): http://<tailscale-ip>:3000
#   - Raw OpenCode API/UI:    http://<tailscale-ip>:4096
#   - mDNS (LAN only):        http://opencode.local:4096
#
# Credentials: username=$USER, password=value stored in Keychain under 'opencode-server'

set -euo pipefail

# Load password from Keychain if not already in environment
if [[ -z "${OPENCODE_SERVER_PASSWORD:-}" ]]; then
  OPENCODE_SERVER_PASSWORD=$(security find-generic-password -a "$USER" -s opencode-server -w 2>/dev/null || true)
fi

if [[ -z "${OPENCODE_SERVER_PASSWORD:-}" ]]; then
  echo "ERROR: No OpenCode server password found."
  echo "Store one in Keychain with:"
  echo "  security add-generic-password -a \"\$USER\" -s opencode-server -w 'your-password'"
  exit 1
fi

export OPENCODE_SERVER_PASSWORD
export OPENCODE_SERVER_USERNAME="${OPENCODE_SERVER_USERNAME:-$USER}"

TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "<tailscale-ip>")
echo "Starting OpenCode server + openportal mobile UI..."
echo "  Mobile UI:  http://${TAILSCALE_IP}:3000"
echo "  OpenCode:   http://${TAILSCALE_IP}:4096"
echo "  mDNS (LAN): http://opencode.local:4096"
echo "  Username:   ${OPENCODE_SERVER_USERNAME}"
echo ""
echo "Press Ctrl-C to stop both."
echo ""

# Start opencode server in background
opencode serve --mdns --port 4096 &
OPENCODE_PID=$!

# Start openportal, pointed at the local opencode server
bunx openportal &
PORTAL_PID=$!

# On exit, kill both
trap 'echo ""; echo "Shutting down..."; kill $OPENCODE_PID $PORTAL_PID 2>/dev/null; wait' EXIT INT TERM

wait $OPENCODE_PID $PORTAL_PID

