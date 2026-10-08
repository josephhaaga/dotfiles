#!/usr/bin/env bash

# Exercise smoke capability gates with fake tools, not a deployed source.
set -euo pipefail
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/home"
cat > "$fixture/bin/fake-tool" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
tool="${0##*/}"
if [ "$tool" = chezmoi ]; then
  [ "$1" = execute-template ]
  printf '%s\n' "$MOCK_KUBERNETES"
else
  printf '%s\n' "$tool $*" >> "$MOCK_TOOL_LOG"
fi
EOF
chmod +x "$fixture/bin/fake-tool"
for tool in chezmoi mise zsh nvim herdr uv node bun go rg fd starship stylua gh opencode neofetch tree-sitter; do
  ln -s fake-tool "$fixture/bin/$tool"
done
export MOCK_TOOL_LOG="$fixture/tools.log"

# Explicitly unset the environment capability; the mocked persisted data is
# authoritative. No real editor, service, model, or container is started.
for enabled in false true; do
  if [ "$enabled" = true ]; then
    ln -s fake-tool "$fixture/bin/kubectl"
    ln -s fake-tool "$fixture/bin/kubelogin"
  fi
  : > "$MOCK_TOOL_LOG"
  HOME="$fixture/home" PATH="$fixture/bin:$PATH" DOTFILES_PROFILE=container \
    DOTFILES_CAPABILITIES='' MOCK_KUBERNETES="$enabled" \
    bash "$DOTFILES/scripts/smoke-test.sh" > "$fixture/output"
  if [ "$enabled" = true ]; then
    grep -Fxq 'kubectl version --client' "$MOCK_TOOL_LOG"
    grep -Fxq 'kubelogin --version' "$MOCK_TOOL_LOG"
  elif grep -Eq '^kubectl|^kubelogin' "$MOCK_TOOL_LOG"; then
    echo 'smoke test invoked opt-in Kubernetes tools without the capability' >&2
    exit 1
  fi
done
printf '%s\n' 'Smoke capability tests passed (default container and Kubernetes opt-in).'
