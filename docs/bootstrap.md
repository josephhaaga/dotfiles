# Bootstrap

## macOS

```bash
mise x chezmoi@2.72.0 -- chezmoi init --apply josephhaaga/dotfiles
```

The detected profile is `desktop`.

### MDM-controlled macOS

Do not use the automatically detected `desktop` profile. Preview and apply the restricted profile explicitly:

```bash
DOTFILES_PROFILE=enterprise mise x chezmoi@2.72.0 -- chezmoi init --apply josephhaaga/dotfiles
```

The enterprise profile leaves native software and macOS services under MDM control. See [Enterprise profile audit](enterprise-profile.md) for the exact install boundary.

## Amazon Linux 2023

```bash
mise x chezmoi@2.72.0 -- chezmoi init --apply josephhaaga/dotfiles
```

Reconnect once after bootstrap so zsh and Docker group membership take effect. Then run:

```bash
bash "$(chezmoi source-path)/scripts/smoke-test.sh"
herdr
```

The server profile runs OpenCode only on VM loopback. See [OpenCode VM
connections](opencode-vm-connections.md) for TUI and OAuth connection paths.

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
DOTFILES_PROFILE=container mise x chezmoi@2.72.0 -- chezmoi init --apply josephhaaga/dotfiles
```

## Updating an existing checkout

After pulling updates, apply the checked-out source:

```bash
git -C "$(chezmoi source-path)" pull --ff-only
chezmoi apply
```

### Source-root migration

The source is now at the repository root. Reinitialize an existing install with
every capability it already uses:

```bash
DOTFILES_CAPABILITIES=kubernetes mise x chezmoi@2.72.0 -- \
  chezmoi init --apply josephhaaga/dotfiles
```

## Safe preview

Preview the active source without changing `$HOME`:

```bash
chezmoi apply --dry-run --source "$PWD" --override-data '{"profile":"desktop"}'
```

The root-level source is initialized by `chezmoi init`; later applies use the
recorded source directory.
