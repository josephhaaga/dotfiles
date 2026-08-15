# Dotfiles

## Workflow

- The new cross-platform chezmoi source is `v2/home/`. It supports the `desktop`, `server`, and `container` profiles described in `docs/profiles.md`.
- `.chezmoiroot` intentionally remains `home` until the reviewed cutover. Editing v2 does not update `$HOME`; `setup` is the explicit v2 apply path.
- Preview v2 with `chezmoi apply --dry-run --source "$PWD/v2/home" --override-data '{"profile":"desktop"}'`.
- chezmoi copies and renders files; it does not symlink them. Do not edit deployed files while developing v2.
- `v2/home/.chezmoidata/packages.yaml` is the package and portable-tool source of truth. Homebrew owns macOS packages, DNF owns Amazon Linux system packages, and mise owns portable tools and runtimes.
- There is no work/personal split. Platform profiles control only capabilities such as GUI applications, services, and local-vault integration.
- Run `bash scripts/validate.sh` before every commit. Use `bash scripts/smoke-test.sh` after applying v2 to a target.

## Configuration Boundaries

- Never manage OAuth tokens, provider credentials, Docker credentials, Slack cookies, shell history, application databases, caches, or agent sessions. See `docs/secrets-v2.md`.
- `~/.config/gh`, `~/.config/gcloud`, and OpenCode authentication remain local runtime state.
- The legacy encrypted files under `home/` must remain encrypted while the old source exists. Do not decrypt them into the repository.
- After changing OpenCode config, commands, or skills, restart OpenCode because it loads configuration at startup.
- Do not reintroduce tmux, a work/personal profile split, removed agent clients, or unpinned runtime downloads without an explicit requirement.

## Packages And Services

- Edit only `v2/home/.chezmoidata/packages.yaml`; `v2/home/dot_config/brew/Brewfile.tmpl` and the mise config are generated from it.
- Third-party Homebrew taps execute formula code. Add one only when the retained application requires it and keep the trust decision visible in review.
- Amazon Linux uses Docker Engine and `crond` under systemd. Docker group membership grants root-equivalent access.
- macOS uses Docker Desktop and the managed Yabai/skhd restart hook.
- Container images own native packages and services; chezmoi must remain usable without `sudo` or systemd in the container profile.
