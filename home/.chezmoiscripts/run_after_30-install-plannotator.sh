#!/bin/bash
set -euo pipefail

# Check the release metadata on every apply, but only run the installer when a
# newer Plannotator version is available. The OpenCode plugin remains declared
# in opencode.json.
latest_version="$(curl -fsSL https://api.github.com/repos/backnotprop/plannotator/releases/latest | jq -r '.tag_name')"

if [ -z "$latest_version" ] || [ "$latest_version" = "null" ]; then
  printf '%s\n' 'Could not determine the latest Plannotator release.' >&2
  exit 1
fi

installed_version=""
if command -v plannotator >/dev/null 2>&1; then
  installed_version="$(plannotator --version | awk '{print $2}')"
fi

if [ "v$installed_version" = "$latest_version" ]; then
  printf 'Plannotator %s is already current.\n' "$installed_version"
  exit 0
fi

printf 'Updating Plannotator from %s to %s.\n' "${installed_version:-not installed}" "$latest_version"
curl -fsSL https://plannotator.ai/install.sh | bash -s -- --version "$latest_version" --non-interactive
