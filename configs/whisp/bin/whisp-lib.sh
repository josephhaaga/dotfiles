#!/usr/bin/env bash
# whisp shared helpers: config access, value substitution, key resolution,
# and status.json writing for the Übersicht OSD overlay.
#
# Source this AFTER config.sh:
#   source "$WHISP_DIR/config.sh"; source "$WHISP_DIR/bin/whisp-lib.sh"

# ---- logging -------------------------------------------------------------

whisp_log() {
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "${WHISP_TAG:-whisp}" "$*" \
    >>"$WHISP_LOG" 2>/dev/null || true
}

# ---- value substitution (OpenCode-style {env:VAR} / {file:~/path}) -------
# Echoes the resolved value of $1. Supports a bare value, {env:NAME}, or
# {file:PATH} (with ~ expansion). Unknown/empty resolves to empty string.
whisp_subst() {
  local value="$1"
  case "$value" in
    '{env:'*'}')
      local name="${value#\{env:}"; name="${name%\}}"
      printf '%s' "${!name-}"
      ;;
    '{file:'*'}')
      local path="${value#\{file:}"; path="${path%\}}"
      case "$path" in
        '~'/*) path="$HOME/${path#'~/'}" ;;
        '~') path="$HOME" ;;
      esac
      if [ -r "$path" ]; then
        # strip a single trailing newline, preserve the rest
        printf '%s' "$(cat "$path")"
      fi
      ;;
    *)
      printf '%s' "$value"
      ;;
  esac
}

# ---- modes.json accessors ------------------------------------------------
# All return empty string when a path is absent. jq `// empty` keeps output clean.

# whisp_mode_field <mode> <jq-key>   e.g. whisp_mode_field ramble provider
whisp_mode_field() {
  "$WHISP_JQ_BIN" -r --arg m "$1" --arg k "$2" \
    '.modes[$m][$k] // empty' "$WHISP_MODES" 2>/dev/null
}

# whisp_provider_field <providerId> <jq-key>
whisp_provider_field() {
  "$WHISP_JQ_BIN" -r --arg p "$1" --arg k "$2" \
    '.provider[$p][$k] // empty' "$WHISP_MODES" 2>/dev/null
}

# whisp_default_field <dotted.path>  e.g. whisp_default_field stt.model
whisp_default_field() {
  "$WHISP_JQ_BIN" -r --arg path "$1" \
    'getpath($path | split(".")) // empty' "$WHISP_MODES" 2>/dev/null \
    <<<"$(cat "$WHISP_MODES")" 2>/dev/null
}

whisp_stt_model() {
  local m; m="$("$WHISP_JQ_BIN" -r '.defaults.stt.model // empty' "$WHISP_MODES" 2>/dev/null)"
  printf '%s' "${m:-ggml-large-v3-turbo.bin}"
}

whisp_stt_language() {
  local l; l="$("$WHISP_JQ_BIN" -r '.defaults.stt.language // empty' "$WHISP_MODES" 2>/dev/null)"
  printf '%s' "${l:-en}"
}

# whisp_mode_exists <mode> -> 0/1
whisp_mode_exists() {
  [ -n "$("$WHISP_JQ_BIN" -r --arg m "$1" '.modes[$m] // empty' "$WHISP_MODES" 2>/dev/null)" ]
}

# ---- API key resolution --------------------------------------------------
# whisp_resolve_key <providerId>: subst(apiKey) -> Keychain whisp-<id> -> empty
whisp_resolve_key() {
  local pid="$1" raw key
  raw="$(whisp_provider_field "$pid" apiKey)"
  key="$(whisp_subst "$raw")"
  if [ -z "$key" ]; then
    key="$(security find-generic-password -s "whisp-$pid" -w 2>/dev/null || true)"
  fi
  printf '%s' "$key"
}

# ---- status.json (drives the Übersicht OSD overlay) ----------------------
# whisp_status <state> [message]
#   states: chord | idle | recording | transcribing | rewriting | inserted | error
# For "chord" we embed the full mode list so the widget can render which-key.
whisp_status() {
  local state="$1" message="${2:-}"
  local mode="" label="" icon="" provider="" model=""

  if [ -f "$WHISP_MODE_FILE" ]; then
    mode="$(cat "$WHISP_MODE_FILE" 2>/dev/null || true)"
  fi
  if [ -n "$mode" ]; then
    label="$(whisp_mode_field "$mode" label)"
    icon="$(whisp_mode_field "$mode" icon)"
    provider="$(whisp_mode_field "$mode" provider)"
    [ -n "$provider" ] && model="$(whisp_provider_field "$provider" model)"
  fi

  local tmp="$WHISP_STATUS.tmp.$$"
  if [ "$state" = "chord" ]; then
    # Embed chord + ordered mode list for the which-key panel.
    "$WHISP_JQ_BIN" -n \
      --arg state "$state" \
      --arg ts "$(date +%s)" \
      --slurpfile cfg "$WHISP_MODES" \
      '{
         state: $state,
         updated_at: ($ts | tonumber),
         chord: ($cfg[0].chord // ""),
         modes: [ $cfg[0].modes | to_entries[] | {
           id: .key,
           key: (.value.key // ""),
           label: (.value.label // .key),
           icon: (.value.icon // ""),
           description: (.value.description // ""),
           provider: (.value.provider // "")
         } ]
       }' >"$tmp" 2>>"$WHISP_LOG"
  else
    "$WHISP_JQ_BIN" -n \
      --arg state "$state" \
      --arg ts "$(date +%s)" \
      --arg mode "$mode" \
      --arg label "$label" \
      --arg icon "$icon" \
      --arg provider "$provider" \
      --arg model "$model" \
      --arg message "$message" \
      '{
         state: $state,
         updated_at: ($ts | tonumber),
         mode: $mode,
         label: $label,
         icon: $icon,
         provider: $provider,
         model: $model,
         message: $message
       }' >"$tmp" 2>>"$WHISP_LOG"
  fi
  mv -f "$tmp" "$WHISP_STATUS" 2>/dev/null || rm -f "$tmp" 2>/dev/null
}

# ---- recording state -----------------------------------------------------
whisp_is_recording() {
  [ -f "$WHISP_PID" ] && kill -0 "$(cat "$WHISP_PID" 2>/dev/null)" 2>/dev/null
}

# whisp_error <message>
# Show a persistent error OSD and (unless WHISP_ERROR_TIMEOUT=0) schedule a
# background auto-clear after WHISP_ERROR_TIMEOUT seconds — but only if the
# overlay is still showing *this* error (so a new chord/recording wins).
whisp_error() {
  local message="${1:-}"
  whisp_status error "$message"
  local timeout="${WHISP_ERROR_TIMEOUT:-8}"
  case "$timeout" in
    ''|0|*[!0-9]*) return 0 ;;  # 0 or non-numeric => stay until dismissed
  esac
  local stamp
  stamp="$("$WHISP_JQ_BIN" -r '.updated_at // empty' "$WHISP_STATUS" 2>/dev/null || true)"
  (
    sleep "$timeout"
    local now
    now="$("$WHISP_JQ_BIN" -r '.updated_at // empty' "$WHISP_STATUS" 2>/dev/null || true)"
    cur="$("$WHISP_JQ_BIN" -r '.state // empty' "$WHISP_STATUS" 2>/dev/null || true)"
    if [ "$cur" = "error" ] && [ "$now" = "$stamp" ]; then
      whisp_status idle
    fi
  ) >/dev/null 2>&1 &
}

