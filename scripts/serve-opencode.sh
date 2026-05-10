#!/bin/bash
# Start OpenCode + openportal mobile UI, accessible over Tailscale.
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
#   - Mobile UI (openportal): http://<tailscale-ip>:3000
#   - Raw OpenCode API/UI:    http://<tailscale-ip>:4096

set -euo pipefail

# Ensure Homebrew binaries are on PATH (needed when script is launched outside a login shell)
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true

# openportal proxies to OpenCode on localhost — password would break it since
# openportal's SDK client sends no auth headers. Tailscale secures the network.
unset OPENCODE_SERVER_PASSWORD OPENCODE_SERVER_USERNAME

TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "<tailscale-ip>")
echo "Starting OpenCode + openportal mobile UI..."
echo "  Mobile UI:  http://${TAILSCALE_IP}:3000"
echo "  OpenCode:   http://${TAILSCALE_IP}:4096"
echo ""
echo "Press Ctrl-C to stop."
echo ""

# Clean up any stale openportal instances that might be holding ports
bunx openportal stop 2>/dev/null || true
bunx openportal clean 2>/dev/null || true

# openportal manages the opencode server internally
# Use current directory explicitly so openportal doesn't confuse stale instances
exec bunx openportal --port 3000 --opencode-port 4096 --hostname 0.0.0.0 --directory "$(pwd)" --name "$(basename "$(pwd)")"

