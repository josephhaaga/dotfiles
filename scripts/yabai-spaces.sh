#!/usr/bin/env bash
# Edit the active chezmoi source, never deployed files.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 "$root/home/dot_local/lib/dotfiles/space_shortcuts.py" serve --source "$root" "$@"
