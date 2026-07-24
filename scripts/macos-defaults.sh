#!/usr/bin/env bash

# Managed macOS preferences. Add settings here rather than ad-hoc commands.
set -euo pipefail

defaults write com.apple.dock autohide -bool true
killall Dock >/dev/null 2>&1 || true
