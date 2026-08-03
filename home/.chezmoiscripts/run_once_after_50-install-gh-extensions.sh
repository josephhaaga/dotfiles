#!/bin/bash
set -euo pipefail

eval "$(/opt/homebrew/bin/brew shellenv)"
gh extension install wham/gh-slackdump 2>/dev/null || true
