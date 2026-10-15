# Tern

The desktop profile manages `~/Library/Application Support/Tern/settings.json`.
Only preferences are tracked; Tern account credentials, sessions, and other
runtime state remain local. The enterprise, server, and container profiles do
not deploy this file, following the existing `Library` profile boundary.

## OpenCode ACP

Tern's `agents.custom` entry launches `~/.local/bin/opencode acp` over stdio.
The template renders an absolute executable path so GUI launches do not depend
on the shell's `PATH`. This configuration matches Tern 0.8.3's settings schema.
It does not enable automatic conversion of terminal commands into ACP chats.

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
