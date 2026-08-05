#!/usr/bin/env bash
#
# Lists Files-and-Folders-style TCC (privacy) grants and flags path-based
# entries whose underlying binary no longer exists on disk -- these are the
# "stale" rows left behind by Homebrew's versioned Cellar/Caskroom upgrades.
#
# System Settings' Files and Folders panel shows only a generic app name per
# row (e.g. three identical "uv" rows) with no way to see which underlying
# path each one corresponds to, so there's no way to pick the right one to
# delete from the UI. This script deletes stale rows directly from the
# database instead, by their exact (unique) path -- the corresponding UI row
# then simply disappears next time System Settings is reopened.
#
# Requires the terminal running this script to have Full Disk Access
# (System Settings > Privacy & Security > Full Disk Access), since TCC.db
# is otherwise unreadable/unwritable even to its owning user.
#
# Usage:
#   find-stale-tcc-entries.sh              # report only, changes nothing
#   find-stale-tcc-entries.sh --clean      # report, then prompt to delete stale rows
#   find-stale-tcc-entries.sh --clean --yes  # report and delete without prompting
set -euo pipefail

db="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
clean=false
assume_yes=false

for arg in "$@"; do
  case "$arg" in
    --clean) clean=true ;;
    --yes) assume_yes=true ;;
    *)
      echo "Usage: $0 [--clean] [--yes]" >&2
      exit 2
      ;;
  esac
done

if [ ! -r "$db" ] || [ ! -w "$db" ]; then
  echo "Cannot read/write $db" >&2
  echo "Grant Full Disk Access to this terminal app, then re-run:" >&2
  echo "  System Settings > Privacy & Security > Full Disk Access" >&2
  exit 1
fi

services_sql="'kTCCServiceSystemPolicyDesktopFolder','kTCCServiceSystemPolicyDocumentsFolder','kTCCServiceSystemPolicyDownloadsFolder','kTCCServiceSystemPolicyNetworkVolumes','kTCCServiceSystemPolicyRemovableVolumes'"

echo "== Files-and-Folders-style grants (path-based clients only) =="
printf '%-8s %-45s %-45s %s\n' "STATUS" "SERVICE" "PATH" "LAST MODIFIED"

stale_file="$(mktemp)"
trap 'rm -f "$stale_file"' EXIT

sqlite3 -separator '|' "$db" "
  SELECT service, client, datetime(last_modified,'unixepoch')
  FROM access
  WHERE service IN ($services_sql)
    AND client_type = 1
  ORDER BY client;
" | while IFS='|' read -r service client last_modified; do
  if [ -e "$client" ]; then
    status="live"
  else
    status="STALE"
    printf '%s\t%s\n' "$service" "$client" >>"$stale_file"
  fi
  printf '%-8s %-45s %-45s %s\n' "$status" "$service" "$client" "$last_modified"
done

echo ""
echo "== Bundle-ID-based grants (GUI apps; can't auto-detect staleness this way) =="
sqlite3 -separator '|' "$db" "
  SELECT service, client, datetime(last_modified,'unixepoch')
  FROM access
  WHERE service IN ($services_sql)
    AND client_type = 0
  ORDER BY client;
"

stale_count=$(wc -l <"$stale_file" | tr -d ' ')
echo ""

if [ "$stale_count" -eq 0 ]; then
  echo "No stale path-based entries found."
  exit 0
fi

echo "$stale_count stale row(s) found (binary path no longer exists on disk)."

if [ "$clean" != true ]; then
  echo "Re-run with --clean to delete them directly from the database."
  echo "(System Settings won't let you pick which duplicate to remove, since"
  echo " it doesn't show paths -- deleting by path here is the reliable fix.)"
  exit 0
fi

if [ "$assume_yes" != true ]; then
  read -r -p "Delete these $stale_count stale row(s) from TCC.db now? [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted, nothing deleted."; exit 0 ;;
  esac
fi

deleted=0
while IFS=$'\t' read -r service client; do
  escaped_client="${client//\'/\'\'}"
  sqlite3 "$db" "DELETE FROM access WHERE service = '$service' AND client = '$escaped_client' AND client_type = 1;"
  deleted=$((deleted + 1))
done <"$stale_file"

echo "Deleted $deleted stale row(s)."
echo "Fully quit and reopen System Settings for the Files and Folders list to refresh."
