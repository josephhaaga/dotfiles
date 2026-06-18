#!/usr/bin/env bash
# whisp-transcribe.sh <wav>
# Runs whisper-cli on a WAV file and prints the raw transcript to stdout.
# All diagnostic output goes to the whisp debug log.
set -euo pipefail

WHISP_TAG=transcribe
DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
# shellcheck source=/dev/null
source "$DIR/config.sh"
# shellcheck source=/dev/null
source "$WHISP_BIN_DIR/whisp-lib.sh"

wav="${1:-$WHISP_CLIP}"

if [ ! -r "$wav" ]; then
  whisp_log "transcribe: input wav not readable: $wav"
  exit 1
fi

model_name="$(whisp_stt_model)"
model_path="$WHISP_MODELS_DIR/$model_name"
lang="$(whisp_stt_language)"

if [ ! -r "$model_path" ]; then
  whisp_log "transcribe: model not found: $model_path (run install.sh to download)"
  exit 2
fi

if ! command -v "$WHISP_WHISPER_BIN" >/dev/null 2>&1; then
  whisp_log "transcribe: $WHISP_WHISPER_BIN not on PATH (brew install whisper-cpp)"
  exit 3
fi

# Output to a temp file base; whisper-cli appends .txt with -otxt.
out_base="$WHISP_STATE_DIR/transcript"
rm -f "$out_base.txt" 2>/dev/null || true

# -np  no prints (only results)   -nt no timestamps
# -otxt + -of writes "<out_base>.txt"
if ! "$WHISP_WHISPER_BIN" \
      -m "$model_path" \
      -f "$wav" \
      -l "$lang" \
      -nt -np \
      -otxt -of "$out_base" \
      >>"$WHISP_LOG" 2>&1; then
  whisp_log "transcribe: whisper-cli failed (see above)"
  exit 4
fi

if [ ! -r "$out_base.txt" ]; then
  whisp_log "transcribe: expected output missing: $out_base.txt"
  exit 5
fi

# Normalize: trim leading/trailing whitespace and collapse blank lines.
# whisper sometimes emits a leading space per segment.
awk 'BEGIN{ORS=""} {gsub(/^[ \t]+|[ \t]+$/,""); if($0!=""){ if(NR>1 && printed) print " "; print $0; printed=1 }}' \
  "$out_base.txt"
