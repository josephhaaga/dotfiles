# Dotfiles

## Workflow

- This repository is a [chezmoi](https://www.chezmoi.io) source directory for a macOS development environment. `.chezmoiroot` points chezmoi at the `home/` subdirectory, which mirrors `$HOME` using chezmoi's naming conventions (`dot_foo` -> `~/.foo`, `encrypted_*.age` -> age-decrypted at apply time, etc.). `scripts/`, `docs/`, `README.md`, and this file live outside `home/` and are not chezmoi-managed.
- chezmoi **copies/renders** from source to target; it does not symlink. Editing a live file under `~/.config/...` does **not** update this repo. Either edit the file under `home/` directly and run `chezmoi apply`, or run `chezmoi edit --apply <target>` / `chezmoi re-add <target>` to pull live edits back into source.
- Package installation is declarative: edit `home/.chezmoidata/packages.yaml` (taps/brews/casks/work_casks), then run `chezmoi apply`. This regenerates `~/.config/brew/Brewfile` (see `home/dot_config/brew/Brewfile.tmpl`) and re-runs `brew bundle` via a `run_onchange_` script keyed to that file's content hash.
- Personal-vs-work machine differences are handled by a single `work` boolean, set once via a `chezmoi init` prompt and stored in `~/.config/chezmoi/chezmoi.toml`. It's referenced by `packages.yaml`'s `work_casks` and by `Brewfile.tmpl`. This is unrelated to the `opencode()` shell function's `OPENCODE_PROFILE=work|personal` runtime toggle, which switches between `opencode.work.json` and `opencode.personal.json` on any machine.
- Run `bash scripts/validate.sh` before committing. It checks shell/JSON syntax, validates the Brewfile template via `chezmoi execute-template`, and runs ShellCheck/Gitleaks when installed; CI runs this same command on macOS.
- `bash scripts/validate.sh --check-installed` additionally runs `brew bundle check` against the machine's already-applied `~/.config/brew/Brewfile`.
- `bash scripts/reconcile.sh` reports undeclared Homebrew/App Store state without changing it. `chezmoi apply` / `chezmoi update` change machine state.
- `bash scripts/status.sh` reports environment health (yabai/skhd services, ZDOTDIR, git config, and whether key chezmoi-managed files match source via `chezmoi verify`).

## Configuration Boundaries

- `~/.config/gh` and `~/.config/gcloud` are **not** chezmoi-managed. They retain local state (OAuth tokens, active gcloud config) and must never be added under `home/`.
- After changing OpenCode config, commands, skills, or plugins under `home/dot_config/opencode/`, restart OpenCode; configuration is loaded only at startup.
- `pi` and `omp` (oh-my-pi) rewrite their own config files at runtime -- `pi` adds keys like `lastChangelogVersion` to `~/.pi/agent/settings.json`, and `omp config set` / `/settings` rewrite `~/.omp/agent/config.yml`. Both are therefore managed with chezmoi's `create_` prefix, which **seeds** the file on a machine that lacks it and then leaves it alone. Editing `home/dot_pi/private_agent/create_settings.json` or `home/dot_omp/private_agent/create_private_config.yml` changes what a *new* machine gets; it does not push the change to a machine where the file already exists. Update those by hand or delete the target and re-apply.
- `~/.pi/agent/auth.json` and `~/.omp/agent/agent.db` hold API keys and OAuth tokens. They are listed in `home/.chezmoiignore` so a stray `chezmoi add ~/.pi` cannot pull credentials into the repo. Never manage them.
- Do not add plaintext credentials. `home/dot_config/zsh/encrypted_private_dot_secrets.age` and `home/dot_config/opencode/encrypted_opencode.personal.json.age` are encrypted with chezmoi's native age support (see `docs/secrets.md`) and must stay encrypted — never re-add their plaintext equivalents to the repo. They are only managed on work machines.
- To edit an encrypted file: `chezmoi decrypt < home/dot_config/<path>.age`, edit, then `chezmoi encrypt < <edited> > home/dot_config/<path>.age` (or use `chezmoi edit --apply <target-path>`, which round-trips this automatically).

## Homebrew And Services

- `home/.chezmoidata/packages.yaml` is the single source of truth for taps/brews/casks (shared) and `work_casks` (installed only when `work = true`). Do not hand-edit `~/.config/brew/Brewfile` -- it is generated from this file.
- Homebrew 6 refuses to load formulae from an untrusted third-party tap. Add such a tap to `trusted_taps` in `packages.yaml` to render `trusted: true` in the Brewfile, keeping the trust decision in review rather than in local `brew trust` state. Trusting a tap lets it run its own formula code, so only add one you trust.
- The local `josephhaaga/dotfiles` tap provides the tracked `Casks/opentypeless.rb` cask; `home/dot_config/brew/Brewfile.tmpl` renders its `file://` path from the `dotfilesRepo` template variable and keeps `trusted: true`.
- Use `scripts/window-manager.sh` to manage yabai/skhd. It also removes obsolete LaunchAgents before starting the current services. A chezmoi `run_onchange_after_` script restarts the window manager automatically whenever `yabairc`/`skhdrc` content changes.
