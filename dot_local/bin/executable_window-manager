#!/bin/bash

set -euo pipefail

uid="$(id -u)"
launch_agents="$HOME/Library/LaunchAgents"

bootout_label() {
  local label="$1"
  local plist="$launch_agents/$label.plist"

  launchctl bootout "gui/$uid" "$plist" >/dev/null 2>&1 || true
}

stop_window_manager() {
  brew services stop josephhaaga/dotfiles/skhd-service >/dev/null 2>&1 || true
  brew services stop josephhaaga/dotfiles/yabai-service >/dev/null 2>&1 || true

  skhd --stop-service >/dev/null 2>&1 || true
  yabai --stop-service >/dev/null 2>&1 || true

  bootout_label homebrew.mxcl.skhd-service
  bootout_label homebrew.mxcl.yabai-service
  bootout_label com.koekeishiya.skhd
  bootout_label com.koekeishiya.yabai
  bootout_label com.asmvik.yabai

  pkill -x skhd >/dev/null 2>&1 || true
  pkill -x yabai >/dev/null 2>&1 || true
}

remove_legacy_yabai_agent() {
  local legacy="$launch_agents/com.koekeishiya.yabai.plist"
  local current="$launch_agents/com.asmvik.yabai.plist"

  if [[ -e "$legacy" && -e "$current" ]]; then
    rm -f "$legacy"
  fi
}

start_window_manager() {
  remove_legacy_yabai_agent

  yabai --start-service
  skhd --start-service
}

status_window_manager() {
  launchctl list | rg 'yabai|skhd' || true
  pgrep -lf '(^|/)(yabai|skhd)( |$)' || true
}

case "${1:-restart}" in
  start)
    start_window_manager
    ;;
  stop)
    stop_window_manager
    ;;
  restart)
    stop_window_manager
    start_window_manager
    ;;
  status)
    status_window_manager
    ;;
  *)
    echo "Usage: $0 [start|stop|restart|status]" >&2
    exit 2
    ;;
esac
