#!/usr/bin/env bash
# whisp shared configuration: paths, binaries, and tunables.
# Sourced by all whisp scripts. No side effects beyond exporting vars.

# Resolve the directory of the whisp install (this file's dir), following symlinks.
# ~/.config is a symlink to the dotfiles repo, so this resolves to the real path.
_whisp_source="${BASH_SOURCE[0]}"
while [ -h "$_whisp_source" ]; do
  _whisp_dir="$(cd -P "$(dirname "$_whisp_source")" >/dev/null 2>&1 && pwd)"
  _whisp_source="$(readlink "$_whisp_source")"
  [[ $_whisp_source != /* ]] && _whisp_source="$_whisp_dir/$_whisp_source"
done
WHISP_DIR="$(cd -P "$(dirname "$_whisp_source")" >/dev/null 2>&1 && pwd)"
export WHISP_DIR

# Core paths
export WHISP_MODES="${WHISP_MODES:-$WHISP_DIR/modes.json}"
export WHISP_MODELS_DIR="${WHISP_MODELS_DIR:-$WHISP_DIR/models}"
export WHISP_BIN_DIR="${WHISP_BIN_DIR:-$WHISP_DIR/bin}"

# Runtime/state (ephemeral, not version-controlled)
export WHISP_STATE_DIR="${WHISP_STATE_DIR:-/tmp/whisp}"
export WHISP_CLIP="$WHISP_STATE_DIR/clip.wav"
export WHISP_PID="$WHISP_STATE_DIR/whisp.pid"
export WHISP_MODE_FILE="$WHISP_STATE_DIR/mode"
export WHISP_STATUS="$WHISP_STATE_DIR/status.json"
export WHISP_RAW="$WHISP_STATE_DIR/raw.txt"
export WHISP_OUT="$WHISP_STATE_DIR/out.txt"
export WHISP_LOG="$WHISP_STATE_DIR/debug.log"

# Tunables
export WHISP_MAX_SECONDS="${WHISP_MAX_SECONDS:-120}"   # safety auto-stop cap
export WHISP_SAMPLE_RATE="${WHISP_SAMPLE_RATE:-16000}" # whisper wants 16 kHz mono
export WHISP_INSERTED_FADE="${WHISP_INSERTED_FADE:-1}" # seconds to show "inserted" OSD
export WHISP_ERROR_TIMEOUT="${WHISP_ERROR_TIMEOUT:-8}" # seconds an error OSD stays before auto-clearing (0 = never)
export WHISP_HTTP_TIMEOUT="${WHISP_HTTP_TIMEOUT:-60}"  # curl max time for LLM calls

# Binaries (allow override; otherwise discovered on PATH)
export WHISP_WHISPER_BIN="${WHISP_WHISPER_BIN:-whisper-cli}"
export WHISP_SOX_BIN="${WHISP_SOX_BIN:-sox}"
export WHISP_JQ_BIN="${WHISP_JQ_BIN:-jq}"

mkdir -p "$WHISP_STATE_DIR" 2>/dev/null || true
