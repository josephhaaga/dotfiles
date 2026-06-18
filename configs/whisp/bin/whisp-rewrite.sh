#!/usr/bin/env bash
# whisp-rewrite.sh <mode> <raw-text>
# Applies a Mode's LLM prompt via its configured provider and prints the
# rewritten text to stdout. On ANY failure it prints the raw text unchanged
# (never lose the transcription) and logs the reason.
#
# Provider types:
#   none               -> passthrough (no LLM)
#   ollama             -> POST {baseURL}/api/chat
#   openai-compatible  -> POST {baseURL}/chat/completions
set -uo pipefail

WHISP_TAG=rewrite
DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
# shellcheck source=/dev/null
source "$DIR/config.sh"
# shellcheck source=/dev/null
source "$WHISP_BIN_DIR/whisp-lib.sh"

mode="${1:-}"
raw="${2:-}"

# Passthrough helper: emit raw and exit 0.
passthrough() { printf '%s' "$raw"; exit 0; }

[ -z "$mode" ] && { whisp_log "rewrite: no mode given"; passthrough; }
[ -z "$raw" ] && { whisp_log "rewrite: empty transcript"; passthrough; }

provider_id="$(whisp_mode_field "$mode" provider)"
prompt="$(whisp_mode_field "$mode" prompt)"

# Mode-level "none" (or missing provider) => verbatim.
if [ -z "$provider_id" ] || [ "$provider_id" = "none" ]; then
  passthrough
fi

ptype="$(whisp_provider_field "$provider_id" type)"
base_url="$(whisp_provider_field "$provider_id" baseURL)"
model="$(whisp_provider_field "$provider_id" model)"

if [ -z "$ptype" ] || [ -z "$base_url" ] || [ -z "$model" ]; then
  whisp_log "rewrite: provider '$provider_id' missing type/baseURL/model"
  passthrough
fi
[ -z "$prompt" ] && prompt="Clean up this transcription. Output only the cleaned text."

# Build a JSON request body with jq (handles all escaping safely).
extract=""        # jq filter to pull the text out of the response
url=""
auth_header=()
body=""

case "$ptype" in
  ollama)
    url="${base_url%/}/api/chat"
    body="$("$WHISP_JQ_BIN" -n \
      --arg model "$model" --arg sys "$prompt" --arg user "$raw" \
      '{model:$model, stream:false, messages:[{role:"system",content:$sys},{role:"user",content:$user}]}')"
    extract='.message.content // empty'
    # Ensure Ollama is reachable; lazy-start if not.
    if ! curl -fsS --max-time 2 "${base_url%/}/api/tags" >/dev/null 2>&1; then
      whisp_log "rewrite: ollama not reachable at $base_url, attempting lazy start"
      if command -v ollama >/dev/null 2>&1; then
        (ollama serve >>"$WHISP_LOG" 2>&1 &)
        for _ in 1 2 3 4 5 6 7 8 9 10; do
          curl -fsS --max-time 2 "${base_url%/}/api/tags" >/dev/null 2>&1 && break
          sleep 1
        done
      fi
    fi
    ;;
  openai-compatible)
    url="${base_url%/}/chat/completions"
    body="$("$WHISP_JQ_BIN" -n \
      --arg model "$model" --arg sys "$prompt" --arg user "$raw" \
      '{model:$model, messages:[{role:"system",content:$sys},{role:"user",content:$user}]}')"
    extract='.choices[0].message.content // empty'
    local_key="$(whisp_resolve_key "$provider_id")"
    if [ -z "$local_key" ]; then
      whisp_log "rewrite: no API key for provider '$provider_id' (env/file/keychain all empty)"
      passthrough
    fi
    auth_header=(-H "Authorization: Bearer $local_key")
    ;;
  *)
    whisp_log "rewrite: unknown provider type '$ptype'"
    passthrough
    ;;
esac

resp="$(curl -fsS --max-time "$WHISP_HTTP_TIMEOUT" \
  -H "Content-Type: application/json" \
  "${auth_header[@]}" \
  -X POST "$url" \
  -d "$body" 2>>"$WHISP_LOG")" || {
    whisp_log "rewrite: HTTP request to $url failed"
    passthrough
  }

out="$(printf '%s' "$resp" | "$WHISP_JQ_BIN" -r "$extract" 2>>"$WHISP_LOG")"

if [ -z "$out" ] || [ "$out" = "null" ]; then
  whisp_log "rewrite: empty/invalid model output; response head: $(printf '%s' "$resp" | head -c 400)"
  passthrough
fi

# Trim a single trailing newline the model may add.
printf '%s' "${out%$'\n'}"
