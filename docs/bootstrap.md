# Bootstrap

## macOS

```bash
git clone https://github.com/josephhaaga/dotfiles ~/Documents/dotfiles
cd ~/Documents/dotfiles
./setup
```

The detected profile is `desktop`.

### MDM-controlled macOS

Do not use the automatically detected `desktop` profile. Preview and apply the restricted profile explicitly:

```bash
chezmoi apply --dry-run --source "$PWD/v2/home" --override-data '{"profile":"enterprise"}'
DOTFILES_PROFILE=enterprise ./setup
```

The enterprise profile leaves native software and macOS services under MDM control. See [Enterprise profile audit](enterprise-profile.md) for the exact install boundary.

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
password. See [OpenCode web access](opencode-web.md) for the web architecture
and [OpenCode VM connections](opencode-vm-connections.md) for all browser, TUI,
and OAuth connection paths.

To connect the desktop TUI to the VM, create an `OpenCode VM` item in the
1Password `Employee` vault and set its `password` field to the password shown
by `/pair` in the VM TUI. The desktop profile keeps the required SSH tunnel
running in the background. Launch the client with:

```bash
opencode-vm
opencode-vm --continue
```

The SSH private key and 1Password value remain local runtime state. The
LaunchAgent uses `~/.ssh/id_ed25519` and requires the VM host key to already be
present in `~/.ssh/known_hosts`.

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
