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

Join the VM to the tailnet interactively. The node identity remains local
runtime state and is not managed by chezmoi:

```bash
sudo tailscale up --operator="$USER"
```

To expose the loopback-only OpenCode web server inside the tailnet, give its
managed service a stable port and proxy it with Tailscale Serve:

```bash
opencode2 service set port 4096
opencode2 service restart
tailscale serve --bg localhost:4096
```

The OpenCode server retains its own generated password in addition to tailnet
access control. Run `opencode2 pair` on the VM to display the credentials.

OpenCode provider credentials are also local runtime state. From an interactive
VM session, run `opencode2`, use `/connect`, and authenticate OpenAI with OAuth
and Anthropic with its API key. Do not copy `~/.local/share/opencode/auth.json`
into this repository.

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
