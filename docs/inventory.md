# Dotfiles Inventory

Every retained item has one installation owner. Anything not listed here is intentionally outside the managed baseline.

## Portable tools

| Tool | Owner | Profiles | Purpose |
|---|---|---|---|
| chezmoi | bootstrap/native | all | Orchestrate files, templates, packages, and services |
| mise | native/bootstrap | all | Install pinned portable CLIs and runtimes; enterprise installs it under the user's home directory |
| zsh, Oh My Zsh, Starship | native + pinned Git checkout + mise | all | Interactive shell, plugins, and prompt |
| Herdr | mise | all | Persistent local and remote terminal sessions |
| Neovim/LazyVim | mise | all | Editor with Go, Python, TypeScript, Docker, JSON, Markdown, and TOML support |
| OpenCode V2 | pinned npm install | all | Primary coding agent |
| Plannotator, Graphify | pinned external OpenCode skills | all | Review and graphing workflows |
| uv, Node, Bun, Go | mise | all | Language runtimes and package execution |
| ripgrep, fd, bat, fzf, tree, jq | mise/native | all | Search and shell utilities |
| gh, Git LFS, git-filter-repo, GnuPG | mise/native | desktop, server | Git and GitHub workflows |
| shellcheck, gitleaks | mise | all | Static and secret checks |
| Docker, Compose | native + mise | all | Container workflows |
| Azure CLI | mise capability `cloud` | opt-in | Azure workflows |
| kubectl, Azure kubelogin | mise capability `kubernetes` | opt-in | Kubernetes workflows |
| gitleaks | mise capability `security` | opt-in | Secret scanning |

The enterprise profile uses an existing, MDM-approved Homebrew installation for CLI formulae, Yabai/skhd, Ghostty, fonts, and OpenChamber. It excludes the rest of the desktop casks.

## macOS applications

| Group | Applications |
|---|---|
| Terminal/windowing | Ghostty, Yabai, skhd, Hack Nerd Font, JetBrains Mono |
| Security/network | 1Password, 1Password CLI, Tailscale |
| Browser/knowledge | Google Chrome, Obsidian |
| AI workspace | OpenChamber |
| Collaboration | Slack, Microsoft Teams, Zoom, Linear, Granola |
| Voice/input | Wispr Flow, Handy; Handy is optional on enterprise |
| Containers | Docker Desktop |

## Deliberately retained fun

Neofetch, asciiquarium, cowsay, lolcat, and ponysay are intentional. They are not cleanup candidates.

## Retained custom workflow

The journal directory and Clerk integration are retained. They are installed by
the source-managed journal bootstrap script; credentials and runtime state are
not managed.

## Removed from the managed baseline

- tmux and TPM; Herdr owns persistent sessions.
- Pi, OMP, Crush, Claude Code, Codex, OMO, agent profiler, OpenPortal Hub, and browser MCP servers.
- Google Drive, Karabiner, Notion, Loom, AI desktop apps, LM Studio, and mitmproxy.
- gcloud/BigQuery, Azure, Heroku, Redis, DuckDB, and FFmpeg.
- `herdr-pr`, save/load scripts, TCC maintenance, stale GitHub scripts, Slack export, and log rotation.
- Fish residue, Neovim example/mono files, Raindrop watchdog, generated browser state, and historical package snapshots.
