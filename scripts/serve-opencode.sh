#!/bin/bash
# Start OpenCode as a server accessible over Tailscale.
#
# Prerequisites:
#   1. Tailscale must be running and authenticated (open the menu bar app or run `tailscale up`)
#   2. Set the server password in Keychain (one-time):
#        security add-generic-password -a "$USER" -s opencode-server -w 'your-password'
#   3. Run this script from inside the project directory you want to work on.
#
# Access from phone:
#   - Tailscale MagicDNS:  http://<your-mac-hostname>.<tailnet>.ts.net:4096
#   - Tailscale IP:        http://100.x.x.x:4096
#   - Local mDNS (LAN):    http://opencode.local:4096
#
# The mobile UI (openportal) runs separately on port 3000:
#   http://<tailscale-hostname>:3000
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

# Print access URLs
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "<tailscale-ip>")
echo "Starting OpenCode server..."
echo "  Tailscale IP:   http://${TAILSCALE_IP}:4096"
echo "  mDNS (LAN):     http://opencode.local:4096"
echo "  Username:       ${OPENCODE_SERVER_USERNAME:-$USER}"
echo ""
echo "  Mobile UI (openportal): bunx openportal  (runs on port 3000)"
echo ""

exec opencode serve --mdns --port 4096
