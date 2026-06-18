#!/usr/bin/env bash
# whisp-record.sh <mode|stop>
# Toggle voice dictation:
#   - If not recording: start capturing mic audio for <mode>.
#   - If recording (any mode, or "stop"): stop, transcribe, rewrite, paste.
#
# State + OSD updates are written to /tmp/whisp/status.json for the Übersicht widget.
set -uo pipefail

WHISP_TAG=record
DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
# shellcheck source=/dev/null
source "$DIR/config.sh"
# shellcheck source=/dev/null
source "$WHISP_BIN_DIR/whisp-lib.sh"

arg="${1:-}"

# ---- stop + pipeline -----------------------------------------------------
run_pipeline() {
  local mode
  mode="$(cat "$WHISP_MODE_FILE" 2>/dev/null || true)"

  # Stop the recorder if alive.
  if [ -f "$WHISP_PID" ]; then
    local pid; pid="$(cat "$WHISP_PID" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      # give sox a moment to flush the WAV header
      for _ in 1 2 3 4 5; do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    fi
    rm -f "$WHISP_PID" 2>/dev/null || true
  fi

  if [ -z "$mode" ] || ! whisp_mode_exists "$mode"; then
    whisp_log "pipeline: unknown/empty mode '$mode'"
    whisp_error "Unknown mode"
    return 1
  fi

  if [ ! -s "$WHISP_CLIP" ]; then
    whisp_log "pipeline: no audio captured"
    whisp_error "No audio captured"
    return 1
  fi

  whisp_status transcribing
  local raw
  raw="$("$WHISP_BIN_DIR/whisp-transcribe.sh" "$WHISP_CLIP" 2>>"$WHISP_LOG")"
  printf '%s' "$raw" >"$WHISP_RAW" 2>/dev/null || true

  if [ -z "$raw" ]; then
    whisp_log "pipeline: empty transcript"
    whisp_error "Nothing transcribed"
    return 1
  fi

  whisp_status rewriting
  local final
  final="$("$WHISP_BIN_DIR/whisp-rewrite.sh" "$mode" "$raw" 2>>"$WHISP_LOG")"
  [ -z "$final" ] && final="$raw"
  printf '%s' "$final" >"$WHISP_OUT" 2>/dev/null || true

  # Copy to clipboard and paste into the focused app via skhd keystroke synth.
  printf '%s' "$final" | pbcopy
  if command -v skhd >/dev/null 2>&1; then
    skhd -k "cmd - v" 2>>"$WHISP_LOG" || whisp_log "pipeline: skhd paste failed"
  else
    whisp_log "pipeline: skhd not found; text left on clipboard"
  fi

  whisp_status inserted
  rm -f "$WHISP_CLIP" 2>/dev/null || true
  sleep "$WHISP_INSERTED_FADE"
  whisp_status idle
}

# ---- start ---------------------------------------------------------------
start_recording() {
  local mode="$1"
  if ! whisp_mode_exists "$mode"; then
    whisp_log "start: unknown mode '$mode'"
    whisp_error "Unknown mode: $mode"
    return 1
  fi
  if ! command -v "$WHISP_SOX_BIN" >/dev/null 2>&1; then
    whisp_log "start: sox not found (brew install sox)"
    whisp_error "sox not installed"
    return 1
  fi

  printf '%s' "$mode" >"$WHISP_MODE_FILE"
  rm -f "$WHISP_CLIP" 2>/dev/null || true

  # Record mono 16 kHz 16-bit WAV from the default input device.
  # `sox -d` reads the default audio input (coreaudio on macOS).
  "$WHISP_SOX_BIN" -d -q -c 1 -r "$WHISP_SAMPLE_RATE" -b 16 "$WHISP_CLIP" \
    trim 0 "$WHISP_MAX_SECONDS" >>"$WHISP_LOG" 2>&1 &
  echo $! >"$WHISP_PID"

  whisp_status recording
}

# ---- dispatch ------------------------------------------------------------
case "$arg" in
  "")
    whisp_log "record: no argument (expected <mode> or 'stop')"
    exit 1
    ;;
  stop)
    run_pipeline
    ;;
  *)
    if whisp_is_recording; then
      # Pressing any mode key (or the same one) while recording => stop+process.
      run_pipeline
    else
      start_recording "$arg"
    fi
    ;;
esac
