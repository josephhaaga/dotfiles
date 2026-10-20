# Tern

The desktop profile manages `~/Library/Application Support/Tern/settings.json`.
Only preferences are tracked; Tern account credentials, sessions, and other
runtime state remain local. The enterprise, server, and container profiles do
not deploy this file, following the existing `Library` profile boundary.

## Agent blocks

Tern's default `agent_command` launches `omp` directly. This keeps the block
on OMP's native runtime, where OMP loads its own MCP configuration and renders
its native agent surface.

The desktop source manages OMP's user MCP file at `~/.omp/agent/mcp.json`.
It mirrors the reviewed servers in OpenCode's configuration using OMP's
`mcpServers` format. The two files are separate because OpenCode and OMP are
separate runtimes.

Do not use `tern acp omp` for the default OMP block when relying on these
servers. In ACP mode, MCP configuration belongs to the ACP client; OMP does
not auto-discover its on-disk MCP configuration for that session.

OpenCode remains available as a separate custom ACP agent. Its MCP servers
remain managed by OpenCode's `opencode.json`.

The repository intentionally does not pin an OMP model. Select an available
model in the OMP agent block before sending its first message. OMP keeps its
provider credentials and session state local.

## OpenCode ACP

Tern's `agents.custom` OpenCode entry launches `~/.local/bin/opencode acp`
over stdio. The template renders an absolute executable path so GUI launches
do not depend on the shell's `PATH`.

OpenCode keeps its own file and terminal tools. OpenCode remains the source of
truth for MCP servers used by the OpenCode ACP agent.

## Ghostty-style keys

Tern mirrors the existing `Ctrl-B` leader shortcuts from Ghostty:

| Keys | Tern action |
| --- | --- |
| `Ctrl-B`, `|` | Split right |
| `Ctrl-B`, `-` | Split down |
| `Ctrl-B`, `H/J/K/L` | Focus left/down/up/right pane |
| `Ctrl-B`, `Z` | Zoom focused pane |
| `Ctrl-B`, `Ctrl-B` | Send literal `Ctrl-B` to the focused program |
| `Ctrl-B`, `:` | Open Tern's command palette |

Ghostty's quick-terminal toggle has no equivalent Tern action, so it is
intentionally not rebound.

## omp and Carly

`omp` is Tern's native Pi-based agent. Its desktop MCP definitions are
managed at `~/.omp/agent/mcp.json`; use `/mcp list` to inspect them and
`/mcp reload` after a local edit. Carly also uses omp and its credentials,
rather than OpenCode's ACP session. Neither omp credentials, its `agent.db`,
nor session data are managed here.

1. Preview the settings and MCP changes:
   ```sh
   chezmoi diff --source "$PWD" --override-data '{"profile":"desktop"}' \
     "$HOME/Library/Application Support/Tern/settings.json" \
     "$HOME/.omp/agent/mcp.json"
   ```
2. Quit Tern before applying so it cannot save stale preferences over the
   files:
   ```sh
   chezmoi apply --source "$PWD" --override-data '{"profile":"desktop"}' \
     "$HOME/Library/Application Support/Tern/settings.json" \
     "$HOME/.omp/agent/mcp.json"
   ```
3. Reopen Tern and start a new OMP agent block in the project directory.
   Existing blocks keep their original process and configuration.

OpenCode uses its existing provider authentication and project configuration.
If authentication is missing, run `opencode auth login` in a terminal. Do not
copy provider credentials into either managed MCP file. OMP's remote MCP
servers use its own local OAuth state when required.

To test question handling in the separate OpenCode ACP agent, ask: “Ask me to
choose between two options using your question tool.” Rendering and
notifications depend on Tern's ACP support.
