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

The server profile installs Caddy and publishes the loopback-only OpenCode web
service at `https://josephhaaga.sh.tribe.ai`. Caddy requires a client
certificate signed by the public CA in `~/.config/caddy/client-ca.pem`; client
private keys and the CA private key remain local runtime state outside this
repository. Caddy reads OpenCode's generated Basic credential from runtime
state and adds it only on the loopback proxy hop, so browsers authenticate with
their client certificate instead of repeatedly prompting for the generated
password. Back up the client CA runtime directory at
`~/.local/share/dotfiles/caddy-ca`; losing its private key requires issuing a
new CA and replacing every device certificate.

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
