# Whiteboard

The macOS desktop package inventory includes `devdotfast/tap/whiteboard`.
The publisher's third-party Homebrew tap executes cask code; it is retained
specifically for Whiteboard. Enterprise, server, and container profiles do not
enable its OpenCode MCP server.

## Finish setup on a new Mac

1. Install the managed Brewfile, or run `brew install --cask devdotfast/tap/whiteboard`.
2. Open Whiteboard and install its CLI from **Settings → Command line** (also offered during welcome setup).
3. Confirm `~/.local/bin/whiteboard version` works.
4. Run `opencode mcp list` and confirm `whiteboard` connects. Use `/reload` in an existing OpenCode session if needed.

Dotfiles configure the desktop MCP server to run `~/.local/bin/whiteboard mcp`.
Whiteboard owns its CLI launcher and local runtime state; chezmoi manages only
the package selection and OpenCode server registration. No hosted login,
trace capture, or cloud storage configuration is required by this setup.
