# Machine Profiles

Profiles are selected automatically by `v2/home/.chezmoi.toml.tmpl` and can be overridden with `DOTFILES_PROFILE` during bootstrap.

## desktop

Apple Silicon macOS. Installs the complete Brewfile, GUI applications, Ghostty, Yabai/skhd, local Obsidian integration, Docker Desktop, and Slack export.

There is no work/personal split. Collaboration tools are part of the normal desktop workflow.

## server

Amazon Linux 2023 x86_64. DNF installs build prerequisites, Docker Engine, zsh, and cronie. mise installs the shared user-space toolchain. No GUI applications or managed secrets are deployed.

Docker group membership is equivalent to root access. The first bootstrap adds the current user to that group; reconnect once before using Docker without `sudo`.

## container

Linux development containers. The image owns native packages. chezmoi installs user configuration and mise tools without enabling systemd services, changing the login shell, or deploying desktop-only workflows.

Use `DOTFILES_PROFILE=container ./setup` when container detection is unavailable.
