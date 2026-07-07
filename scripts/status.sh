#!/bin/bash

# Check whether the local environment matches expected dotfiles configuration.
# Exits non-zero if any check fails.
#
# Status logic lives in scripts/lib/status-checks.sh (shared with neofetch).

status=0

# Resolve this script's directory so we can source the shared helper reliably.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/status-checks.sh
. "$SCRIPT_DIR/lib/status-checks.sh"

# Renderer callback for status_emit_all. See status-checks.sh for the arg contract.
render() {
  local kind="$1" section="$2" label="$3" result="$4" value="$5"
  case "$kind" in
    section)
      echo ""
      echo "$section"
      ;;
    check)
      if [ "$result" -eq 0 ]; then
        echo "  [ok]  $label${value:+  $value}"
      else
        echo "  [!!]  $label${value:+: $value}"
        status=1
      fi
      ;;
    info)
      if [ -n "$label" ]; then
        printf "  %-10s %s\n" "$label" "$value"
      else
        echo "  $value"
      fi
      ;;
  esac
}

echo "=== dotfiles status ==="

status_emit_all render

echo ""
if [ "$status" -eq 0 ]; then
  echo "All checks passed."
else
  echo "One or more checks failed."
fi

exit $status
