# Bootstrap

## macOS

```bash
git clone https://github.com/josephhaaga/dotfiles ~/Documents/dotfiles
cd ~/Documents/dotfiles
./setup
```

The detected profile is `desktop`.

## Amazon Linux 2023

```bash
sudo dnf install -y git
mkdir -p ~/Documents
git clone https://github.com/josephhaaga/dotfiles.git ~/Documents/dotfiles
cd ~/Documents/dotfiles
./setup
```

Reconnect once after bootstrap so zsh and Docker group membership take effect. Then run:

```bash
bash scripts/smoke-test.sh
herdr
```

From another machine, attach with:

```bash
herdr --remote josephhaaga.sh.tribe.ai
```

Detaching the client leaves panes and agents running on the VM.

## Dev container

The image must provide `curl`, `git`, `zsh`, a C/C++ build toolchain, and CA certificates. As the non-root development user:

```bash
DOTFILES_PROFILE=container ./setup
```

## Safe preview

Preview the active source without changing `$HOME`:

```bash
chezmoi apply --dry-run --source "$PWD" --override-data '{"profile":"desktop"}'
```

`./setup` is the explicit action that applies v2.
