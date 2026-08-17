# Secrets Policy

The managed source does not include secret values by default.

Excluded runtime state includes:

- GitHub and cloud CLI OAuth configuration.
- OpenCode provider and MCP authentication.
- Tailscale node identity and auth keys.
- Docker registry credentials.
- Slack cookies and keychain material.
- Obsidian vault content beyond the selected app setting.
- Shell history, agent sessions, caches, and application databases.

The server uses the forwarded SSH agent for GitHub access. Agent providers are authenticated manually on each machine. If encrypted managed secrets become necessary later, add one purpose-specific file and gate it behind a `managedSecrets` feature instead of reintroducing a work/personal profile split.
