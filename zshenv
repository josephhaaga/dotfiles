# uv
export PATH="/Users/josephhaaga/.local/bin:$PATH"
export ZDOTDIR="$HOME/.config/zsh"

# Raindrop Workshop — local debugger endpoint and session metadata
export RAINDROP_LOCAL_DEBUGGER="http://localhost:5899/v1/"
export RAINDROP_EVENT_METADATA='{"userId":"josephhaaga"}'

# To set/update: security add-generic-password -a "$USER" -s opencode-server -w 'your-password'
_opencode_pw=$(security find-generic-password -a "$USER" -s opencode-server -w 2>/dev/null)
if [[ -n "$_opencode_pw" ]]; then
  export OPENCODE_SERVER_PASSWORD="$_opencode_pw"
  export OPENCODE_SERVER_USERNAME="$USER"
fi
unset _opencode_pw
