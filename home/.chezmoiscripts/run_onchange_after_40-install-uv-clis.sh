#!/bin/bash
set -euo pipefail

eval "$(/opt/homebrew/bin/brew shellenv)"
uv tool install --force git+https://github.com/josephhaaga/clerk.git
uv tool install --force pre-commit
uv tool install --force frogmouth
