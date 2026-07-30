# Dotfiles

## Workflow

- This repository is the declarative source for a macOS development environment. Edit tracked sources under `configs/` and `scripts/`, not their live `~/` destinations.
- Run `bash scripts/validate.sh` before committing. It checks shell and JSON syntax, parses both Brewfiles, and runs ShellCheck/Gitleaks when installed; CI runs this same command on macOS.
- `bash scripts/validate.sh --check-installed` additionally compares the machine with both Brewfiles, so use it only when Homebrew state is relevant.
- `bash scripts/reconcile.sh` reports undeclared Homebrew/App Store state without changing it. `scripts/install.sh` and `scripts/update.sh` change machine state.

## Configuration Boundaries

- `scripts/install.sh` symlinks only declarative OpenCode files and directories. Preserve `~/.config/opencode` dependencies, credentials, and local `opencode.jsonc`; do not replace that directory wholesale.
- The same applies to `~/.config/gh` and `~/.config/gcloud`: they retain local state and are deliberately not symlinked.
- After changing OpenCode config, commands, skills, or plugins under `configs/opencode/`, restart OpenCode; configuration is loaded only at startup.
- Do not add plaintext credentials. `configs/zsh/.secrets`, `configs/gh/hosts.yml`, and `configs/opencode/opencode.personal.json` have a documented SOPS migration plan in `docs/secrets.md`.

## Homebrew And Services

- `configs/brew/Brewfile` is the shared profile. `configs/brew/Brewfile.work` is an optional work-only overlay installed with `scripts/install.sh --work`; keep shared applications in the base Brewfile.
- The local `josephhaaga/dotfiles` tap in the base Brewfile provides the tracked `Casks/opentypeless.rb` cask; retain its `file://` path and `trusted: true` declaration.
- Use `scripts/window-manager.sh` to manage yabai/skhd. It also removes obsolete LaunchAgents before starting the current services.
