# dotfiles

Cross-platform development environment managed by [chezmoi](https://www.chezmoi.io/) and [mise](https://mise.jdx.dev/).

The managed source supports:

- Apple Silicon macOS desktops.
- MDM-controlled macOS development laptops.
- Amazon Linux 2023 development servers.
- Non-root Linux development containers.

## Safe Preview

The repository root is the active chezmoi source. Previous configurations remain available through Git history.

Preview the desktop profile without applying it:

```bash
chezmoi apply --dry-run \
  --source "$PWD" \
  --override-data '{"profile":"desktop"}'
```

## Bootstrap

Bootstrap a fresh machine or DevPod with mise and chezmoi:

```bash
mise x chezmoi@2.72.0 -- chezmoi init --apply josephhaaga/dotfiles
```

The profile is detected automatically:

| Profile | Target | Native packages |
|---|---|---|
| `desktop` | macOS Apple Silicon | Homebrew and casks |
| `enterprise` | MDM-controlled macOS | Approved Homebrew CLI/window tools |
| `server` | Amazon Linux 2023 | DNF and systemd services |
| `container` | Dev containers | Owned by the container image |

Set `DOTFILES_PROFILE=enterprise` or `DOTFILES_PROFILE=container` to override detection.

Cloud, Kubernetes, and secret-scanning tools are opt-in capabilities. Set
`DOTFILES_CAPABILITIES=cloud,kubernetes,security` during bootstrap or apply.

## Remote Development

Herdr owns persistent sessions on the VM. Attach directly from a local terminal:

```bash
herdr --remote josephhaaga.sh.tribe.ai
```

Alternatively, SSH first and run `herdr`. Detaching leaves remote panes and agents running.

## Commands

```bash
bash scripts/validate.sh
bash scripts/smoke-test.sh
chezmoi apply --source "$PWD"
chrome-extensions
link-agent-skills
```

Run `chrome-extensions` manually to audit the Chrome Default profile's extension
inventory, grouped into installed and missing extensions. Applying dotfiles does
not run this informational audit. To open Chrome Web Store pages for missing
extensions, run `chrome-extensions --install-missing` explicitly.

`link-agent-skills` exposes the checked-out personal skills repository to
OpenCode, Pi, OMP, and Codex through `~/.agents/skills`. It links every skill
from the default source, `~/Documents/skills/skills`, individually, so
package-managed skills already in that directory remain untouched. It never
modifies the checkout or replaces an existing path. Set `PERSONAL_SKILLS_DIR`
when the repository lives elsewhere.

The managed mise lockfile includes baseline platform entries added by mise.
When deliberately updating tools, review and copy lockfile changes back into
`dot_config/mise/mise.lock` so subsequent applies do not undo them.

## Documentation

- [`docs/inventory.md`](docs/inventory.md): retained and removed applications.
- [`docs/profiles.md`](docs/profiles.md): platform behavior and boundaries.
- [`docs/whiteboard.md`](docs/whiteboard.md): opt-in Whiteboard-first OpenCode mode, task identity, feedback limits, and recovery.
- [`docs/opencode-multiplayer.md`](docs/opencode-multiplayer.md): specification for collaborative OpenCode sessions, deliberation polls, and child-session forks.
- [`docs/bootstrap.md`](docs/bootstrap.md): setup and safe preview commands.
- [`docs/secrets-v2.md`](docs/secrets-v2.md): unmanaged credentials and runtime state.
- [`docs/vm-web-access.md`](docs/vm-web-access.md): mTLS-protected VM web access.
- [`docs/vm-hosted-reports.md`](docs/vm-hosted-reports.md): publish responsive reports to approved devices.
- [`docs/openchamber-workflows.md`](docs/openchamber-workflows.md): native workflow defaults, offline contract tests, and explicit manual setup.

The inventory intentionally keeps Neofetch, asciiquarium, cowsay, lolcat, and ponysay. tmux is not part of the managed baseline.
