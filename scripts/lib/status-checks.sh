#!/usr/bin/env bash
#
# status-checks.sh — shared dotfiles status logic.
#
# Single source of truth for environment checks used by both:
#   - scripts/status.sh        (human-readable [ok]/[!!] report)
#   - configs/neofetch/config.conf (custom neofetch info lines)
#
# This file only DEFINES functions; sourcing it has no side effects.
#
# Public API:
#   status_emit_all <callback>
#
# The callback is invoked once per status item with these positional args:
#   $1 kind    : "check" | "info" | "section"
#   $2 section : group name (e.g. "Symlinks", "yabai")
#   $3 label   : item label (e.g. "brew installed"); empty for "section"
#   $4 result  : "0" (pass) | "1" (fail) | "" (n/a, for info/section)
#   $5 value   : detail/value string (may be empty)
#
# "check" items carry a pass/fail result. "info" items are plain key/value
# details with no pass/fail. "section" items mark the start of a group.
#
# Any "check" (or a non-running window-manager service) with result=1 means the overall
# environment is unhealthy; consumers can track that themselves by watching
# the result field.

# Emit one record by calling the caller-supplied callback.
# Usage: _se <callback> <kind> <section> <label> <result> <value>
_se() {
  local cb="$1"; shift
  "$cb" "$1" "$2" "$3" "$4" "$5"
}

status_emit_all() {
  local cb="$1"
  [ -n "$cb" ] || return 2

  local r

  # --- chezmoi-managed files ---
  # chezmoi copies/renders files rather than symlinking, so "is this file
  # correct" now means "does it match chezmoi's source state", checked with
  # `chezmoi verify` (exits non-zero on drift or if untracked/missing).
  _se "$cb" section "chezmoi" "" "" ""

  if command -v chezmoi >/dev/null 2>&1; then
    if chezmoi verify "$HOME/.config/yabai/yabairc" >/dev/null 2>&1; then
      r=0; else r=1; fi
    _se "$cb" check "chezmoi" "~/.config/yabai/yabairc matches source" "$r" ""

    if chezmoi verify "$HOME/.clerkrc" >/dev/null 2>&1; then
      r=0; else r=1; fi
    _se "$cb" check "chezmoi" "~/.clerkrc matches source" "$r" ""
  else
    _se "$cb" info "chezmoi" "" "" "chezmoi not installed (skipped)"
  fi

  # --- git config ---
  _se "$cb" section "git config" "" "" ""

  if grep -qF "path = $HOME/.config/git/dotfiles.gitconfig" "$HOME/.gitconfig" 2>/dev/null; then
    r=0; else r=1; fi
  _se "$cb" check "git config" "~/.gitconfig includes dotfiles git config" "$r" ""

  if git config --get alias.glo >/dev/null 2>&1; then r=0; else r=1; fi
  _se "$cb" check "git config" "git alias 'glo' is resolvable" "$r" ""

  # --- Shell ---
  _se "$cb" section "Shell" "" "" ""

  if grep -q 'ZDOTDIR' "$HOME/.zshenv" 2>/dev/null; then r=0; else r=1; fi
  _se "$cb" check "Shell" "ZDOTDIR set in ~/.zshenv" "$r" ""

  # --- Tools ---
  _se "$cb" section "Tools" "" "" ""

  local t
  for t in brew uv gh; do
    if command -v "$t" >/dev/null 2>&1; then r=0; else r=1; fi
    _se "$cb" check "Tools" "$t installed" "$r" ""
  done

  # --- yabai (neofetch-style detail lines) ---
  _se "$cb" section "yabai" "" "" ""

  local yabai_scripts="$HOME/.config/yabai/scripts"
  if command -v yabai >/dev/null 2>&1; then
    local ver running have_jq
    ver="$(yabai --version 2>/dev/null)"
    if yabai -m query --spaces >/dev/null 2>&1; then
      running="running"
    else
      running="not responding"
    fi

    # Service state is a health check (result reflects responsiveness).
    if [ "$running" = "running" ]; then r=0; else r=1; fi
    _se "$cb" check "yabai" "service" "$r" "${running}${ver:+ ($ver)}"

    _se "$cb" info "yabai" "layout" "" "$(yabai -m config layout 2>/dev/null || echo '?')"

    have_jq=1; command -v jq >/dev/null 2>&1 || have_jq=0
    if [ "$have_jq" -eq 1 ] && [ "$running" = "running" ]; then
      _se "$cb" info "yabai" "displays" "" \
        "$(yabai -m query --displays 2>/dev/null | jq -r 'length')"
      _se "$cb" info "yabai" "spaces" "" \
        "$(yabai -m query --spaces 2>/dev/null \
          | jq -r '[.[] | "\(.index):\(.type)/\(.windows|length)w\(if .["has-focus"] then "*" else "" end)"] | join("  ")')"
      _se "$cb" info "yabai" "rules" "" \
        "$(yabai -m rule --list 2>/dev/null | jq -r 'length')"
      _se "$cb" info "yabai" "signals" "" \
        "$(yabai -m signal --list 2>/dev/null \
          | jq -r 'group_by(.event)[] | "\(.[0].event)x\(length)"' | paste -sd' ' -)"
    fi

    # Custom scripts present + wired as signals.
    if [ -d "$yabai_scripts" ]; then
      local f name mark
      for f in "$yabai_scripts"/*.sh; do
        [ -e "$f" ] || continue
        name="$(basename "$f")"
        mark="present"
        [ -x "$f" ] || mark="present (not executable)"
        if [ "$have_jq" -eq 1 ] && [ "$running" = "running" ] && \
           yabai -m signal --list 2>/dev/null \
             | jq -e --arg a "$f" 'any(.[]; (.action // "") | contains($a))' >/dev/null 2>&1; then
          mark="$mark, wired"
        fi
        _se "$cb" info "yabai" "script" "" "$name [$mark]"
      done
    fi
  else
    _se "$cb" info "yabai" "" "" "not installed (skipped)"
  fi

  # --- skhd ---
  _se "$cb" section "skhd" "" "" ""

  if command -v skhd >/dev/null 2>&1; then
    local skhd_ver skhd_running
    skhd_ver="$(skhd --version 2>/dev/null)"
    if pgrep -x skhd >/dev/null 2>&1; then
      skhd_running="running"
      r=0
    else
      skhd_running="not running"
      r=1
    fi
    _se "$cb" check "skhd" "service" "$r" "${skhd_running}${skhd_ver:+ ($skhd_ver)}"
  else
    _se "$cb" info "skhd" "" "" "not installed (skipped)"
  fi
}
