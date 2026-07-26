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

All four tools are now integrated: OpenCode, Claude Desktop, Claude Code, and Codex.

## Codex

Codex config lives in `~/.codex/`. The CLI now ships bundled inside **ChatGPT.app** (the
standalone `codex-app` cask is deprecated); the installer symlinks it to
`/opt/homebrew/bin/codex`.

- **`scribe/codex/install.sh`** (project repo) — symlinks the CLI, adds the Seekstone MCP
  (`codex mcp add`), and generates the Stop hook (`~/.codex/hooks.json`) from `$HOME`. Idempotent.

Capture is **deterministic** (Codex supports Claude-Code-style lifecycle hooks). The scribe
(`scribe/codex/codex_scribe.py` in the project repo) writes attributed entries. After install:
`codex login`, then trust the hook via `/hooks` (Codex re-flags it whenever the script changes).

## Install

The scribe is developed in its own repo and installs itself. `scripts/install.sh` calls the
project's `scribe/install.sh` automatically when the repo is present at
`~/Documents/code/setup-ai-native-dev-env`. To (re)wire it manually:

```bash
~/Documents/code/setup-ai-native-dev-env/scribe/install.sh              # tools + catch-up agent
~/Documents/code/setup-ai-native-dev-env/scribe/install.sh --with-synthesis   # + end-of-day KB staging
```

All machine-specific config (Claude Code/Codex hooks, Claude Desktop MCP block, launchd plists)
is GENERATED from `$HOME` at install time — nothing with absolute paths is committed. Scripts
run via `uv run` (no system python3 needed). Each tool's installer lives beside its scribe
script in the project repo (`scribe/<tool>/install.sh`).

## Claude Desktop

Claude Desktop's config (`~/Library/Application Support/Claude/claude_desktop_config.json`)
lives outside `~/.config` and the app **rewrites it on launch**, so it is not symlinked.
Instead:

- **`scribe/claude-desktop/install.sh`** (project repo) — quits Claude Desktop (if running) and
  `jq`-merges a generated Obsidian MCP block into the live config, preserving the app's own
  preferences. Run it once per machine, then launch Claude Desktop.

Capture on Desktop is **instruction-driven** (no session hooks): create a Project with the
scribe instructions from the project repo (`scribe/claude-desktop/README.md`). Deterministic
Desktop capture is deferred to the Phase 6 transcript daemon.

Use the absolute npx path (`/opt/homebrew/bin/npx`) — GUI apps don't inherit the shell PATH.

## Phase 6 daemon (deterministic Claude Desktop capture) — REMOVED

A background daemon that read Claude Desktop's IndexedDB was built and then **removed**: that
store is dominated by the composer input-box draft, so it captured unsent text (including
Getting-Started tutorial suggestions), not sent messages. There's no reliable on-disk way to
tell sent from draft. See the project repo `docs/DECISIONS.md` D9.

Claude Desktop auto-capture is therefore **not** deterministic. Use either:
- the `obsidian-scribe` **skill** (on request: "log this") — reads the real conversation, and
- Phase 3 Project instructions.

Deterministic per-turn capture is reliable for **OpenCode, Claude Code, and Codex** (real hooks).
