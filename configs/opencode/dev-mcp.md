# dev-mcp shim

`dev-mcp` is a thin Python wrapper that exposes the BuzzFeed internal `dev mcp`
command as a stdio MCP server, making it compatible with any MCP client (OpenCode,
Claude Code, Cursor, etc.).

## Why it exists

The `dev mcp` command launches a [FastMCP](https://github.com/jlowin/fastmcp) stdio
server that exposes internal BuzzFeed tooling — Jira, BigQuery, Google Docs, agent
management — via the Model Context Protocol.

The wrapper solves one specific problem: `dev mcp` writes startup banner messages to
stdout via `dev.platform.ui.print`. Those messages corrupt the MCP JSON-RPC stream,
breaking any client that expects clean JSON on stdin/stdout.

The shim patches `dev.platform.ui.print` to write to **stderr** instead of stdout
before the dev shell starts, so all banner/status output is silently redirected away
from the MCP stream. FastMCP's own stdio transport writes directly to stdout and is
unaffected.

A secondary concern is portability. The VS Code extension calls `tech-api` directly
over HTTPS using credentials in VSCode's SecretStorage. That approach doesn't work
for other MCP clients. By delegating to `dev mcp`, auth is handled automatically
through the dev secrets system (SOPS-encrypted `secrets_v2.yml`, already present
after `dev/install`).

## What the shim does, step by step

1. Changes the working directory to the mono repo root (required for relative paths
   like `secrets_v2.yml`).
2. Sets `VIRTUAL_ENV` and `PATH` to simulate `source dev/env/bin/activate`, so
   `env.verify()` inside the dev shell passes.
3. Adds `dev/src/python` to `sys.path` so the `dev` package is importable.
4. Rewrites `sys.argv` to `["dev-mcp", "mcp"]` so the dev shell routes to the
   `Mcp` command.
5. Patches `dev.platform.ui.print` → writes to stderr.
6. Calls `main()` from the dev shell's `main.py` — the rest runs normally.

## Installation

The shim is a single executable file. Copy it to your OpenCode (or Claude Code)
config directory and make it executable:

```bash
# OpenCode (global config)
cp /path/to/dotfiles/configs/opencode/dev-mcp ~/.config/opencode/dev-mcp
chmod +x ~/.config/opencode/dev-mcp

# Or for Claude Code
cp /path/to/dotfiles/configs/opencode/dev-mcp ~/.config/claude/dev-mcp
chmod +x ~/.config/claude/dev-mcp
```

> **Note:** The shashbang at the top of the file points to the venv Python inside
> the mono repo (`/Users/josephhaaga/Documents/code/mono/dev/env/bin/python3`).
> Update all hardcoded paths in the shim to match your local mono repo location
> before copying.

## Configuration

### OpenCode

Add the following to `~/.config/opencode/opencode.json` (or your project-level
`opencode.json`):

```json
{
  "mcp": {
    "dev-mcp": {
      "type": "local",
      "command": ["/Users/YOU/.config/opencode/dev-mcp"],
      "enabled": true,
      "environment": {}
    }
  }
}
```

Set `"enabled": false` to disable the server without removing the config.

### Claude Code

Add the server under `mcpServers` in `~/.claude/claude_desktop_config.json` (Claude
Desktop) or run:

```bash
claude mcp add dev-mcp -- /Users/YOU/.config/claude/dev-mcp
```

Which produces an entry like:

```json
{
  "mcpServers": {
    "dev-mcp": {
      "command": "/Users/YOU/.config/claude/dev-mcp",
      "args": []
    }
  }
}
```

## Prerequisites

- mono repo cloned and `dev/install` completed (provides the venv and
  `secrets_v2.yml`)
- Paths inside the shim updated to match your username / mono repo location
