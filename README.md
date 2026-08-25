# dotfiles

Cross-platform development environment managed by [chezmoi](https://www.chezmoi.io/) and [mise](https://mise.jdx.dev/).

The v2 source supports:

- Apple Silicon macOS desktops.
- Amazon Linux 2023 development servers.
- Non-root Linux development containers.

## Safe Preview

The active chezmoi source is `v2/home/`. Previous configurations remain available through Git history.

Preview the desktop profile without applying it:

```bash
chezmoi apply --dry-run \
  --source "$PWD" \
  --override-data '{"profile":"desktop"}'
```

## Bootstrap

Clone the repository and explicitly run `setup` when ready to apply v2:

```bash
git clone https://github.com/josephhaaga/dotfiles ~/Documents/dotfiles
cd ~/Documents/dotfiles
./setup
```

The profile is detected automatically:

| Profile | Target | Native packages |
|---|---|---|
| `desktop` | macOS Apple Silicon | Homebrew and casks |
| `server` | Amazon Linux 2023 | DNF and systemd services |
| `container` | Dev containers | Owned by the container image |

Set `DOTFILES_PROFILE=container` to override detection.

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
```

## Update Dashboard

The private dashboard compares pinned tool and Neovim plugin versions with their
upstream releases each morning. The server profile publishes it at
`https://josephhaaga.sh.tribe.ai/private/updates/` behind the same client-certificate
authentication as OpenCode.

Build and preview it locally:

```bash
update-dashboard
```

Publish generated HTML privately by default, or explicitly make it public:

```bash
publish-html ./report.html weekly-report
publish-html --public ./report.html shared-report
```

Published directories must contain `index.html`. Public artifacts are available
without a client certificate, so inspect them for secrets before publishing.

## Podcast Briefings

The `/podcast` OpenCode skill turns a PDF into a two-host ElevenLabs briefing
and publishes it to a tokenized RSS feed compatible with Apple Podcasts. The
feed token is generated on the VM at runtime and remains outside this
repository. Episodes expire after 30 days.

Print the feed URL without publishing an episode:

```bash
publish-podcast --feed-url
```

## Documentation

- [`docs/inventory.md`](docs/inventory.md): retained and removed applications.
- [`docs/profiles.md`](docs/profiles.md): platform behavior and boundaries.
- [`docs/bootstrap.md`](docs/bootstrap.md): setup and safe preview commands.
- [`docs/secrets-v2.md`](docs/secrets-v2.md): unmanaged credentials and runtime state.

The inventory intentionally keeps Neofetch, asciiquarium, cowsay, lolcat, and ponysay. tmux is not part of v2.
