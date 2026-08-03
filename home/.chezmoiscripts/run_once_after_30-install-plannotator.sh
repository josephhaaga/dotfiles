#!/bin/bash
set -euo pipefail

# Installs the Plannotator CLI and OpenCode review commands. The OpenCode
# plugin itself is declared in dot_config/opencode/opencode.json.
curl -fsSL https://plannotator.ai/install.sh | bash
