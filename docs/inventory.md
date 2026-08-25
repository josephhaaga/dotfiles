# Dotfiles v2 Inventory

Every retained item has one installation owner. Anything not listed here is intentionally outside the v2 baseline.

## Portable tools

| Tool | Owner | Profiles | Purpose |
|---|---|---|---|
| chezmoi | bootstrap/native | all | Orchestrate files, templates, packages, and services |
| mise | native/bootstrap | all | Install pinned portable CLIs and runtimes; enterprise installs it under the user's home directory |
| zsh, Oh My Zsh, Starship | native + pinned Git checkout + mise | all | Interactive shell, plugins, and prompt |
| Herdr | mise | all | Persistent local and remote terminal sessions |
| Neovim/LazyVim | mise | all | Editor with Go, Python, TypeScript, Docker, JSON, Markdown, and TOML support |
| OpenCode V2 | pinned npm install | all | Primary coding agent |
| Plannotator, Graphify, terminal-browser | vendor/OpenCode config | all | Review, graphing, and terminal browser workflows |
| uv, Node, Bun, Go | mise | all | Language runtimes and package execution |
| ripgrep, fd, bat, fzf, tree, jq | mise/native | all | Search and shell utilities |
| gh, Git LFS, git-filter-repo, GnuPG | mise/native | desktop, server | Git and GitHub workflows |
| shellcheck, gitleaks | mise | all | Static and secret checks |
| Docker, Compose, kubectl | native + mise | all | Containers and Kubernetes client tooling |

The enterprise profile uses an existing, MDM-approved Homebrew installation for CLI formulae, Yabai/skhd, Ghostty, and fonts. It excludes the rest of the desktop casks.

## macOS applications

| Group | Applications |
|---|---|
| Terminal/windowing | Ghostty, Yabai, skhd, Hack Nerd Font, JetBrains Mono |
| Security/network | 1Password, 1Password CLI, Tailscale |
| Browser/knowledge | Google Chrome, Obsidian |
| Collaboration | Slack, Microsoft Teams, Zoom, Linear, Granola |
| Voice/input | Wispr Flow, Handy |
| Containers | Docker Desktop |

## Deliberately retained fun

Neofetch, asciiquarium, cowsay, lolcat, and ponysay are intentional. They are not cleanup candidates.

## Retained custom workflow

`slackmd` is desktop-only. It combines `gh-slackdump` with a Markdown formatter and can decrypt the Slack desktop cookie to download private images. OAuth state and cookies remain unmanaged.

## Removed from v2

- tmux and TPM; Herdr owns persistent sessions.
- Pi, OMP, Crush, Claude Code, Codex, OMO, agent profiler, OpenPortal Hub, and browser MCP servers.
- Google Drive, Karabiner, Notion, Loom, AI desktop apps, LM Studio, OpenTypeless, and mitmproxy.
- gcloud/BigQuery, Azure, Heroku, Redis, DuckDB, and FFmpeg.
- Clerk/journal automation, `herdr-pr`, save/load scripts, TCC maintenance, stale GitHub scripts, and log rotation.
- Fish residue, Neovim example/mono files, Raindrop watchdog, generated browser state, and historical package snapshots.
