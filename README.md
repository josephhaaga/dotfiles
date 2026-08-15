# dotfiles

Cross-platform development environment managed by [chezmoi](https://www.chezmoi.io/) and [mise](https://mise.jdx.dev/).

The v2 source supports:

- Apple Silicon macOS desktops.
- Amazon Linux 2023 development servers.
- Non-root Linux development containers.

## Safe Preview

The active chezmoi source is `v2/home/`. The legacy `home/` source remains in the repository for rollback but is no longer applied.

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

## Documentation

- [`docs/inventory.md`](docs/inventory.md): retained and removed applications.
- [`docs/profiles.md`](docs/profiles.md): platform behavior and boundaries.
- [`docs/bootstrap.md`](docs/bootstrap.md): setup and safe preview commands.
- [`docs/secrets-v2.md`](docs/secrets-v2.md): unmanaged credentials and runtime state.

The inventory intentionally keeps Neofetch, asciiquarium, cowsay, lolcat, and ponysay. tmux is not part of v2.
