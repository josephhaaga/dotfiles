# Enterprise Profile Audit

Use this profile only with an explicit environment override:

```bash
DOTFILES_PROFILE=enterprise ./setup
```

macOS defaults to `desktop`; the repository cannot reliably detect MDM enrollment.

## Bootstrap

`setup` installs chezmoi `v2.72.0` into `~/.local/bin` only when chezmoi is not already available. It downloads the version-pinned installer, verifies its SHA-256 checksum, and then runs `chezmoi init --apply --force` against `v2/home`.

## Installed Software

The enterprise profile requires Homebrew to be available already; it will not bootstrap Homebrew on an MDM machine. `brew bundle` installs:

- All formulae under `packages.macos.brews`, including age, Bash, chezmoi, CMake, Git tools, GnuPG, jq, mise, tree, wget, Yabai/skhd, and the deliberately retained fun commands.
- The trusted third-party `asmvik/formulae` tap required by Yabai/skhd.
- Ghostty, Hack Nerd Font, and JetBrains Mono. No other casks are included.

It also installs the following software under the user's home directory:

- mise `v2026.8.6`, using a checksum-verified installer.
- The versions in `v2/home/.chezmoidata/packages.yaml` under `packages.mise`: bat, bun, fd, fzf, GitHub CLI, gitleaks, Go, herdr, kubectl, Neovim, Node.js, ripgrep, ShellCheck, Starship, StyLua, tealdeer, and uv.
- The npm packages under `packages.npm`: the OpenCode V2 CLI and tree-sitter CLI.
- Oh My Zsh at pinned Git revision `97e11051e2f8053b1d694788d1cb4b0dbb1e2365`.
- Neofetch `7.1.0`, using a checksum-verified download.
- Plannotator `0.27.7` and terminal-browser through checksum-verified vendor installers.

The profile may run `chsh` to select an already approved shell from `/etc/shells`. Starting Yabai runs its existing `sudo -n yabai --load-sa` hook; it cannot prompt for or create privileged access.

## Explicitly Excluded

The enterprise profile excludes all desktop-only paths through `.chezmoiignore` and profile-gated scripts:

- Homebrew bootstrap and all casks except Ghostty and the two fonts.
- Docker Desktop, macOS defaults, and repository-managed LaunchAgents.
- The local Obsidian vault integration and OpenCode VM environment file.
- All OpenCode MCP servers and every model provider other than GitHub Copilot.
- Slack export binaries, the Slack cookie reader, and the `gh-slackdump` extension.
- Server-only Caddy configuration, Docker service setup, DNF packages, and systemd services.

## Managed Configuration

chezmoi deploys the portable configuration plus Ghostty, Yabai/skhd, and the window-manager helper. This includes zsh, Git aliases, mise, Neovim, Starship, tealdeer, neofetch, herdr, and OpenCode configuration, commands, and skills.

OpenCode is configured differently on this profile than on the others:

- No MCP servers are declared. The Agent MCP endpoint and the Obsidian server are both omitted, because the enterprise network blocks unreviewed outbound endpoints.
- `enabled_providers` is set to `["github-copilot"]`, so every other model provider is ignored regardless of what credentials are present. GitHub Copilot is the only approved provider; authenticate through the device flow at `https://github.com/login/device`.

Authentication remains local runtime state and is never managed.

## Private npm Registry

The enterprise network serves npm through a private mirror and terminates TLS with an inspecting proxy, so any fallback to `registry.npmjs.org` fails with `SELF_SIGNED_CERT_IN_CHAIN`.

The registry itself is configured outside this repository, in the Node installation's global npmrc. That file is not read when `npm install --global` is given a `--prefix`, because `--prefix` also relocates where npm looks for the global npmrc. `run_onchange_after_50-install-agent-tools.sh.tmpl` therefore resolves the registry with `npm config get registry` before `--prefix` takes effect and passes it explicitly with `--registry`.

Do not manage npm credentials here. The auth token lives in `~/.npmrc` and stays local runtime state.

The setup also writes `ZDOTDIR` to `~/.zshenv`. Because `chezmoi init` uses `--force`, preview the apply first if the account already has files at managed paths.

## Secret Boundary

No secret values are managed. The following paths are always ignored:

- GitHub, Google Cloud, Docker, and OpenCode authentication state.
- Shell history, OAuth tokens, provider credentials, cookies, caches, databases, and agent sessions.
- SSH private keys, Caddy private keys, and application keychain material.
- Obsidian vault content beyond the desktop-only app setting.

Run `gitleaks detect --source . --no-git` before bootstrap to repeat the repository secret scan. The authoritative policy is in `docs/secrets-v2.md`.
