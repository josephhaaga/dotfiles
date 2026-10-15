# Tern

The desktop profile manages `~/Library/Application Support/Tern/settings.json`.
Only preferences are tracked; Tern account credentials, sessions, and other
runtime state remain local. The enterprise, server, and container profiles do
not deploy this file, following the existing `Library` profile boundary.

## OpenCode ACP

Tern's `agents.custom` entry launches `~/.local/bin/opencode acp` over stdio.
The template renders an absolute executable path so GUI launches do not depend
on the shell's `PATH`. `auto_acp` converts a typed `opencode` command into a
Tern ACP chat; `keep_tui` leaves the other first-party agent CLIs unchanged.
OpenCode keeps its own file and terminal tools, and OpenCode remains the source
of truth for MCP servers.

The repository intentionally does not pin an OpenCode model. Select an
available OpenAI model in Tern's Agent chat before sending its first message;
that selection belongs to the ACP session. Tern does not store provider
credentials; OpenCode's existing credentials remain local runtime state.

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

`omp` is Tern's separate Pi-based harness. Run it directly in a Tern terminal
pane when evaluating it; authenticate and choose a model with omp itself.
Carly also uses omp and its credentials, rather than OpenCode's ACP session.
Neither omp credentials, its `agent.db`, nor session data are managed here.

1. Preview the settings change:
   ```sh
   chezmoi diff --source "$PWD" --override-data '{"profile":"desktop"}' "$HOME/Library/Application Support/Tern/settings.json"
   ```
2. Quit Tern before applying so it cannot save stale preferences over the file:
   ```sh
   chezmoi apply --source "$PWD" --override-data '{"profile":"desktop"}' "$HOME/Library/Application Support/Tern/settings.json"
   ```
3. Reopen Tern, select **OpenCode** in the agent picker, and start a conversation
   in the project directory.

OpenCode uses its existing provider authentication and project configuration.
If authentication is missing, run `opencode auth login` in a terminal. Do not
copy provider credentials into this file. MCP servers already configured in
OpenCode do not need to be duplicated in Tern.

To test question handling, ask: “Ask me to choose between two options using
your question tool.” Rendering and notifications depend on Tern's ACP support.
