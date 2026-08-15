#!/usr/bin/env bash

set -euo pipefail

plannotator_version="0.27.3"
curl -fsSL https://plannotator.ai/install.sh |
  bash -s -- --version "$plannotator_version" --non-interactive

# The vendor installer verifies release checksums before replacing the binary.
curl -fsSL https://terminal-browser.sh/install | bash
