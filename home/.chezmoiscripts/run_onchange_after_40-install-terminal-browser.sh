#!/usr/bin/env bash

set -euo pipefail

# The vendor installer verifies the release checksum before installing the
# standalone CLI and its agent skills.
curl -fsSL https://terminal-browser.sh/install | bash
