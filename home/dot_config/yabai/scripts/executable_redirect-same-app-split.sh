#!/usr/bin/env sh
#
# redirect-same-app-split.sh
#
# Triggered by yabai's `window_created` signal. Prevents a new window from
# splitting an existing window OF THE SAME APP. Instead, warps the new window
# onto the largest window of a *different* app on the same space.
#
# Example: Chrome occupies the left half and is focused. Opening a second Chrome
# window would normally split Chrome into two skinny halves. This script instead
# warps the new Chrome window onto whatever different-app window is largest
# (e.g. the terminal on the right), leaving the original Chrome full-size.
#
# Defers to native BSP whenever it already does the right thing.
#
# Env provided by yabai: $YABAI_WINDOW_ID (id of the newly created window).

set -eu

# yabai lives in Homebrew's bin, which is not guaranteed to be on the minimal
# PATH that signals execute under. Resolve a concrete binary.
if command -v yabai >/dev/null 2>&1; then
  YABAI="$(command -v yabai)"
elif [ -x /opt/homebrew/bin/yabai ]; then
  YABAI=/opt/homebrew/bin/yabai
elif [ -x /usr/local/bin/yabai ]; then
  YABAI=/usr/local/bin/yabai
else
  exit 0
fi

# jq is required to parse query output.
if command -v jq >/dev/null 2>&1; then
  JQ="$(command -v jq)"
elif [ -x /usr/bin/jq ]; then
  JQ=/usr/bin/jq
elif [ -x /opt/homebrew/bin/jq ]; then
  JQ=/opt/homebrew/bin/jq
else
  exit 0
fi

new_id="${YABAI_WINDOW_ID:-}"
[ -n "$new_id" ] || exit 0

# --- Query the new window, tolerating a brief placement race ---------------
# On window_created the window may not be fully placed in the tree yet. Retry a
# small, bounded number of times before giving up.
new_json=""
i=0
while [ "$i" -lt 5 ]; do
  if new_json="$("$YABAI" -m query --windows --window "$new_id" 2>/dev/null)" \
    && [ -n "$new_json" ] && [ "$new_json" != "null" ]; then
    break
  fi
  i=$((i + 1))
  new_json=""
  sleep 0.02
done
[ -n "$new_json" ] || exit 0

# Skip floating windows (manage=off) -- they aren't part of the BSP tree.
is_floating="$(printf '%s' "$new_json" | "$JQ" -r '.["is-floating"]')"
[ "$is_floating" = "true" ] && exit 0

new_app="$(printf '%s' "$new_json" | "$JQ" -r '.app')"
new_space="$(printf '%s' "$new_json" | "$JQ" -r '.space')"
[ -n "$new_space" ] && [ "$new_space" != "null" ] || exit 0

# Only act on BSP spaces. Stack/float layouts don't split.
space_type="$("$YABAI" -m query --spaces --space "$new_space" 2>/dev/null \
  | "$JQ" -r '.type')"
[ "$space_type" = "bsp" ] || exit 0

# --- Gather all windows on the space ---------------------------------------
space_windows="$("$YABAI" -m query --windows --space "$new_space" 2>/dev/null)"
[ -n "$space_windows" ] && [ "$space_windows" != "null" ] || exit 0

# Count managed (non-floating) windows. With <= 2 there is no better placement
# than native BSP (either nothing to split, or the single first split is
# unavoidable), so defer.
managed_count="$(printf '%s' "$space_windows" \
  | "$JQ" '[.[] | select(.["is-floating"] == false)] | length')"
[ "$managed_count" -gt 2 ] 2>/dev/null || exit 0

# --- Identify the split target ---------------------------------------------
# With `window_placement second_child`, a new window splits the window that was
# focused immediately BEFORE it appeared. A new window steals focus, so we
# cannot look for the currently focused window. Instead we ask yabai for the
# "recent" window -- the previously focused window, which yabai tracks natively
# and which reliably points at the pre-new-window focus even after the new
# window grabs focus.
#
# The recent pointer can be transiently empty right as the window is created,
# so retry a few times (bounded) before giving up.
target_id=""
j=0
while [ "$j" -lt 5 ]; do
  target_id="$("$YABAI" -m query --windows --window recent 2>/dev/null \
    | "$JQ" -r '.id // empty')"
  [ -n "$target_id" ] && [ "$target_id" != "$new_id" ] && break
  target_id=""
  j=$((j + 1))
  sleep 0.02
done

# If we still could not determine the previously focused window, defer.
[ -n "$target_id" ] || exit 0

# The target must be a managed (non-floating) window ON this space. A floating
# window (e.g. a picture-in-picture popout) is never a real BSP split target,
# and a window on another space is irrelevant.
target_valid="$(printf '%s' "$space_windows" | "$JQ" -r --argjson tid "${target_id:-0}" '
  [.[] | select(.id == $tid and .["is-floating"] == false)] | length
')"
[ "$target_valid" = "1" ] || exit 0

# Only intervene when the split target is the SAME app as the new window.
# Compare case-insensitively: yabai occasionally reports an app under slightly
# different casing (e.g. "Ghostty" vs "ghostty") for otherwise identical apps.
target_app="$(printf '%s' "$space_windows" | "$JQ" -r --argjson tid "$target_id" '
  [.[] | select(.id == $tid)] | first | .app // empty
')"
new_app_lc="$(printf '%s' "$new_app" | tr '[:upper:]' '[:lower:]')"
target_app_lc="$(printf '%s' "$target_app" | tr '[:upper:]' '[:lower:]')"
[ "$target_app_lc" = "$new_app_lc" ] || exit 0

# --- Choose the warp destination -------------------------------------------
# Largest different-app, non-floating window (by frame area), excluding the new
# window itself. App comparison is case-insensitive so windows of the same app
# reported under different casing are correctly treated as the same app (and
# thus NOT chosen as a destination).
dest_id="$(printf '%s' "$space_windows" | "$JQ" -r --argjson nid "$new_id" --arg app "$new_app_lc" '
  [ .[]
    | select(.id != $nid)
    | select(.["is-floating"] == false)
    | select((.app | ascii_downcase) != $app)
  ]
  | sort_by(.frame.w * .frame.h)
  | last
  | .id // empty
')"

# No different-app window to warp onto -> defer to native behavior.
[ -n "$dest_id" ] || exit 0

# Re-insert the new window by splitting the chosen destination.
"$YABAI" -m window "$new_id" --warp "$dest_id" >/dev/null 2>&1 || exit 0
