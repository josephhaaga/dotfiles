# Obsidian knowledge base + AI scribe

An Obsidian vault at `~/Documents/obsidian-vault` acts as a shared personal knowledge
base. AI dev tools read and write it via the [Seekstone](https://github.com/shaqmughal/seekstone)
MCP server, and a background **scribe** logs work automatically as you go.

Full project (architecture, plan, vault template, scribe source) lives in
`~/Documents/code/setup-ai-native-dev-env`. This doc covers only what these dotfiles carry.

## What these dotfiles provide

- **`configs/opencode/opencode.json`** — an `obsidian` MCP entry running Seekstone, plus the
  scribe registered in the `plugin` array.
- **`configs/opencode/local-plugins/scribe.ts`** — the scribe. On `session.idle` it appends a
  timestamped checkpoint (summary of the last prompt + tool-action count) to today's daily
  note; on `session.deleted` it writes an end marker. File-direct writes, so a crash or long
  session still leaves a trail. Debounced (90s) and grouped under a per-session heading.

`scripts/install.sh` already symlinks `configs/opencode/local-plugins` and `opencode.json`,
so both deploy on a fresh machine with no extra steps. Seekstone itself needs no install —
it runs via `npx -y seekstone` (first run downloads it).

## Per-machine configuration

Seekstone needs an **absolute** vault path (OpenCode JSON can't expand `~`). The value in
`opencode.json` is:

```json
"environment": { "SEEKSTONE_VAULT": "/Users/josephhaaga/Documents/obsidian-vault" }
```

On a machine with a different vault location, update that one line. The scribe falls back to
`~/Documents/obsidian-vault` when `SEEKSTONE_VAULT` is unset, so it stays consistent.

## Vault

The vault is its own git repo (not tracked here). Structure: `Daily/` (scribe target),
`Projects/`, `Topics/` (Memoriki-style wiki), `Inbox/`, `Templates/`. Rules agents follow
live in the vault's `AGENTS.md` / `CLAUDE.md`.

> **Template note:** vault template frontmatter must be static YAML — Obsidian's
> `{{date:...}}` placeholders break Seekstone's on-disk YAML parse. Real dates are injected
> by the scribe at write time.

## Other tools (planned)

Claude Code, Claude Desktop, and Codex will get the same Seekstone MCP wiring; their configs
will be added here as each is integrated.
