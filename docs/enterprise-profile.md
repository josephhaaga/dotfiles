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
- The npm packages under `packages.npm`: the OpenCode V2 CLI, tree-sitter CLI, and the enterprise-only Plannotator OpenCode plugin. npm uses the machine's existing private-registry and custom-CA configuration.
- Oh My Zsh at pinned Git revision `97e11051e2f8053b1d694788d1cb4b0dbb1e2365`.
- Neofetch `7.1.0`, using a checksum-verified download.
- Plannotator `0.27.7` through a checksum-verified vendor installer.

The profile may run `chsh` to select an already approved shell from `/etc/shells`. Starting Yabai runs its existing `sudo -n yabai --load-sa` hook; it cannot prompt for or create privileged access.

## Explicitly Excluded

The enterprise profile excludes all desktop-only paths through `.chezmoiignore` and profile-gated scripts:

- Homebrew bootstrap and all casks except Ghostty and the two fonts.
- Docker Desktop, macOS defaults, and repository-managed LaunchAgents.
- The local Obsidian vault integration and OpenCode VM environment file.
- Every OpenCode MCP server not individually reviewed for this profile, and every model provider other than GitHub Copilot.
- Slack export binaries, the Slack cookie reader, and the `gh-slackdump` extension.
- Server-only Caddy configuration, Docker service setup, DNF packages, and systemd services.
- terminal-browser, whose installer host the proxy answers with 503.

## Managed Configuration

chezmoi deploys the portable configuration plus Ghostty, Yabai/skhd, and the window-manager helper. This includes zsh, Git aliases, mise, Neovim, Starship, tealdeer, neofetch, herdr, and OpenCode configuration, commands, and skills.

OpenCode is configured differently on this profile than on the others:

- MCP servers are opt-in per name rather than inherited from the other profiles. Only `playwright` is declared. The Agent MCP endpoint and the Obsidian server are omitted, because neither is reviewed for the enterprise network. `scripts/validate.sh` enforces the allowlist, so adding a server means adding its name there and recording that its outbound behaviour was reviewed.
- The Playwright server runs with `--browser chrome` so it drives the installed Google Chrome. Playwright's own browser builds come from `cdn.playwright.dev` rather than the private npm mirror, and selecting the system browser avoids that download entirely. The npm package itself resolves through Artifactory normally.
- `enabled_providers` is set to `["github-copilot"]`, so every other model provider is ignored regardless of what credentials are present. GitHub Copilot is the only approved provider; authenticate through the device flow at `https://github.com/login/device`.
- The Plannotator plugin is installed by npm through Artifactory and loaded from its local `dist/server.js`. This avoids OpenCode's bundled bun installer, which does not read npm's registry or custom-CA configuration.

Authentication remains local runtime state and is never managed.

## OpenCode Configuration Syntax

`opencode.json.tmpl` is written in legacy (v1) syntax: `plugin`, `permission` as a keyed object, and `mcp` keyed directly by server name. This is deliberate and applies to every profile, not just this one.

OpenCode 1.x rejects the v2 syntax outright and refuses to start. The opencode2 preview migrates v1 on read, rewriting `plugin` to `plugins`, the `permission` map to a `permissions` rule array, `mcp` to `mcp.servers`, and `enabled_providers` to `experimental.policies`. Compatibility therefore runs one way only, and v1 is the single form both channels accept. Machines with both binaries installed share one `~/.config/opencode/opencode.json`, so a per-channel file is not an option.

The trap is that OpenCode 1.x accepts unknown top-level keys silently. Writing the v2 plurals does not raise an error, it just stops taking effect: before this was corrected, `plugins` and `permissions` were being ignored entirely on 1.x, so the plugin never loaded and the subagent denials were never enforced. `scripts/validate.sh` rejects the v2 spellings for this reason.

## Private npm Registry

The enterprise network serves npm through a private mirror and terminates TLS with an inspecting proxy, so any fallback to `registry.npmjs.org` fails with `SELF_SIGNED_CERT_IN_CHAIN`.

The registry itself is configured outside this repository, in the Node installation's global npmrc. That file is not read when `npm install --global` is given a `--prefix`, because `--prefix` also relocates where npm looks for the global npmrc. `run_onchange_after_50-install-agent-tools.sh.tmpl` therefore resolves the registry with `npm config get registry` before `--prefix` takes effect and passes it explicitly with `--registry`.

Do not manage npm credentials here. The auth token lives in `~/.npmrc` and stays local runtime state.

bun does not read `~/.npmrc` at all, so it otherwise ignores the mirror and reaches for `registry.npmjs.org`, which the proxy answers with 503. Plannotator bypasses this path by loading its npm-installed local file. `run_onchange_after_06-configure-bun-registry.sh.tmpl` still generates `~/.bunfig.toml` from the existing npmrc for any future package-form plugins, writing it `0600`. The token is matched against the configured registry host rather than the first line of the file, so an npmrc holding several hosts cannot pair a token with the wrong registry. Like `~/.npmrc`, the generated file is local credential state and is never committed.

## Certificate Trust

The proxy re-signs outbound HTTPS with an internal root CA. macOS tools trust it from the System keychain, but language runtimes ship their own bundles and ignore the keychain, so `run_onchange_after_05-export-corporate-ca.sh.tmpl` exports the root at apply time. The certificate is not secret, but it is machine-local trust state, so it is exported rather than committed, and the export is best-effort so a machine off this network still applies cleanly.

Two files are written, because the consuming variables have opposite semantics:

- `~/.config/ssl/corporate-ca.pem` holds the corporate root alone, for `NODE_EXTRA_CA_CERTS`, which *appends* to Node's built-in bundle.
- `~/.config/ssl/ca-bundle.pem` holds the system roots plus the corporate root, for `SSL_CERT_FILE` and `REQUESTS_CA_BUNDLE`, which *replace* the trust store outright.

Getting that backwards fails in a confusing direction. Pointing `SSL_CERT_FILE` at the corporate root alone makes uv distrust everything else, so installs fail against PyPI, which is not intercepted and serves an ordinary public chain.

Note that npm's registry setting does not help here. It covers npm's own traffic only, so package postinstall scripts that download their own binaries still need the CA: tree-sitter-cli fetches a release asset from github.com over plain Node https.

The enterprise OpenCode configuration loads Plannotator from npm's local installation instead of asking OpenCode's bundled Bun runtime to download it. The setup also writes `ZDOTDIR` to `~/.zshenv`. Because `chezmoi init` uses `--force`, preview the apply first if the account already has files at managed paths.

## Secret Boundary

No secret values are managed. The following paths are always ignored:

- GitHub, Google Cloud, Docker, and OpenCode authentication state.
- Shell history, OAuth tokens, provider credentials, cookies, caches, databases, and agent sessions.
- SSH private keys, Caddy private keys, and application keychain material.
- Obsidian vault content beyond the desktop-only app setting.

Run `gitleaks detect --source . --no-git` before bootstrap to repeat the repository secret scan. The authoritative policy is in `docs/secrets-v2.md`.
