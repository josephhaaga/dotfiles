# Machine Profiles

Profiles are selected automatically by `home/.chezmoi.toml.tmpl` and can be overridden with `DOTFILES_PROFILE` during bootstrap.

## desktop

Apple Silicon macOS. Installs the complete Brewfile, GUI applications, Ghostty, Yabai/skhd, and Docker Desktop.

There is no work/personal split. Collaboration tools are part of the normal desktop workflow.

## enterprise

MDM-controlled macOS. Uses an existing, MDM-approved Homebrew installation for the shared CLI formulae, Yabai/skhd, Ghostty, fonts, and OpenChamber. It also installs the pinned user-space and agent toolchains. Handy is attempted as an optional cask and does not fail the apply if Workbrew policy rejects it. It does not install other personal or collaboration applications, Docker Desktop, LaunchAgents, or macOS preferences.

Select it explicitly during bootstrap because MDM enrollment cannot be detected reliably:

```bash
DOTFILES_PROFILE=enterprise ./setup
```

See [Enterprise profile audit](enterprise-profile.md) for the complete install and managed-file boundary.

## server

Amazon Linux 2023 x86_64. DNF installs build prerequisites, Docker Engine, zsh, and cronie. mise installs the shared user-space toolchain. No GUI applications or managed secrets are deployed.

Docker group membership is equivalent to root access. The first bootstrap adds the current user to that group; reconnect once before using Docker without `sudo`.

## container

Linux development containers. The image owns native packages. chezmoi installs user configuration and mise tools without enabling systemd services, changing the login shell, or deploying desktop-only workflows.

Use `DOTFILES_PROFILE=container ./setup` when container detection is unavailable.

## Optional capabilities

Capabilities enable additional tools independently of the machine profile:

- `cloud`: Azure CLI.
- `kubernetes`: kubectl and Azure kubelogin.
- `security`: gitleaks.

For initial bootstrap, set `DOTFILES_CAPABILITIES` to a comma-separated list:

```bash
DOTFILES_CAPABILITIES=kubernetes ./setup
```

On an existing machine, enable Kubernetes without applying unrelated configuration:

1. Set `capabilities = ["kubernetes"]` under `[data]` in `~/.config/chezmoi/chezmoi.toml`. Preserve any other enabled capabilities in the list.
2. From this repository, run `chezmoi apply --source "$PWD" ~/.config/mise/config.toml`.
3. Run `mise install kubectl aqua:Azure/kubelogin`, then `kubectl version --client`.

An installed mise tool can still report "No version is set for shim" when its capability is disabled. Enable the capability rather than using `mise use -g`: chezmoi regenerates the global mise configuration and would overwrite that change.
