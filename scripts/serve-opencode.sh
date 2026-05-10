#!/bin/bash
# Start OpenCode + openportal mobile UI, accessible over Tailscale.
#
# openportal manages the OpenCode server internally; this script handles
# auth and prints the access URLs.
#
# Prerequisites:
#   1. Tailscale must be running and authenticated (open the menu bar app or run `tailscale up`)
#   2. Set the server password in Keychain (one-time):
#        security add-generic-password -a "$USER" -s opencode-server -w 'your-password'
#   3. Run this script from inside the project directory you want to work on.
#
# Access from phone (requires Tailscale connected on phone):
#   - Mobile UI (openportal): http://<tailscale-ip>:3000
#   - Raw OpenCode API/UI:    http://<tailscale-ip>:4096
#
# Credentials: username=$USER, password=value stored in Keychain under 'opencode-server'

set -euo pipefail

# Ensure Homebrew binaries are on PATH (needed when script is launched outside a login shell)
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true

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
echo "Starting OpenCode + openportal mobile UI..."
echo "  Mobile UI:  http://${TAILSCALE_IP}:3000"
echo "  OpenCode:   http://${TAILSCALE_IP}:4096"
echo "  Username:   ${OPENCODE_SERVER_USERNAME}"
echo ""
echo "Press Ctrl-C to stop."
echo ""

# Clean up any stale openportal instances that might be holding ports
bunx openportal stop 2>/dev/null || true
bunx openportal clean 2>/dev/null || true

# openportal manages the opencode server internally
exec bunx openportal --port 3000 --opencode-port 4096 --hostname 0.0.0.0

