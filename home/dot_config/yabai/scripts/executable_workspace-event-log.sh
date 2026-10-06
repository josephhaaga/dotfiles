#!/usr/bin/env sh

# Record a privacy-conscious, local-only workspace event. Yabai runs this from
# signals; skhd also calls it before explicit workspace shortcuts. The log
# deliberately excludes window titles, URLs, keystrokes, and window contents.

set -u

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
export PATH

event="${1:?event name is required}"
state_dir="${WORKSPACE_TRACKER_DIR:-$HOME/.local/state/workspace-tracker}"
today="$(date -u +%F)"
log_file="$state_dir/events-$today.jsonl"

umask 077
mkdir -p "$state_dir"
chmod 700 "$state_dir"

# Keep enough history for weekly-pattern analysis without retaining an
# unbounded activity record. State is generated locally and never managed by
# chezmoi or committed to Git.
find "$state_dir" -type f -name 'events-*.jsonl' -mtime +30 -delete 2>/dev/null || true

window_id="${YABAI_WINDOW_ID:-}"
space_id="${YABAI_SPACE_ID:-}"
display_id="${YABAI_DISPLAY_ID:-}"
details='{}'

if [ -n "$window_id" ]; then
  details="$(yabai -m query --windows --window "$window_id" 2>/dev/null |
    jq -c '{app, space, display, floating: .["is-floating"], sticky: .["is-sticky"], native_fullscreen: .["is-native-fullscreen"]}' 2>/dev/null || printf '{}')"
elif [ -n "$space_id" ]; then
  details="$(yabai -m query --spaces --space "$space_id" 2>/dev/null |
    jq -c '{space: .index, display, native_fullscreen: .["is-native-fullscreen"]}' 2>/dev/null || printf '{}')"
fi

jq -cn \
  --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg event "$event" \
  --arg window_id "$window_id" \
  --arg space_id "$space_id" \
  --arg display_id "$display_id" \
  --argjson details "$details" \
  '{
    at: $at,
    event: $event,
    window_id: ($window_id | if . == "" then null else . end),
    signal_space_id: ($space_id | if . == "" then null else . end),
    signal_display_id: ($display_id | if . == "" then null else . end)
  } + $details' >> "$log_file"
