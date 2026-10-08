# Secrets Policy

The managed source does not include secret values by default.

The enterprise profile also excludes the desktop's 1Password VM reference, personal SSH tunnel LaunchAgent, and Slack cookie tooling.

Excluded runtime state includes:

- GitHub and cloud CLI OAuth configuration.
- OpenCode provider and MCP authentication.
- OpenChamber settings/preferences, OAuth, pairing cookies/tokens, project mappings, and scheduled-task runtime state. Only a separate nonsecret workflow overlay is source-managed; see [native workflows](openchamber-workflows.md).
- Caddy client-certificate and client-CA private keys.
- Docker registry credentials.
- Slack cookies and keychain material.
- Journal content beyond the managed Clerk configuration.
- Shell history, agent sessions, caches, and application databases.

The server uses the forwarded SSH agent for GitHub access. Agent providers are authenticated manually on each machine. If encrypted managed secrets become necessary later, add one purpose-specific file and gate it behind a `managedSecrets` feature instead of reintroducing a work/personal profile split.
