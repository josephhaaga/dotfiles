---
name: obsidian-scribe
description: "Log conversations to the user's Obsidian knowledge base. Use when the user asks to 'log this', 'save to my notes', 'update my vault', or wants a project/topic note updated. Deterministic per-turn capture is already handled by a global hook; this skill is for richer, on-request summaries."
---

## What this skill does

Write to the user's Obsidian vault (at `SEEKSTONE_VAULT`, default `~/Documents/obsidian-vault`)
using the **Obsidian MCP tools** (Seekstone: `append_periodic_note`, `create_note`, `patch_note`,
`patch_frontmatter`, `search`, `read_note`).

> Note: deterministic **per-turn** capture is handled outside this skill by a global Stop hook
> (Claude Code) that reads the real conversation. This skill is for the richer, on-request
> logging below — it does not need to run every turn.

## On request ("log this", "update my notes", etc.)

1. Append a concise conversation summary to today's daily note via `append_periodic_note`
   (period `daily`), under a short `## Conversation: <topic>` heading: what was discussed,
   decisions, and follow-ups.
2. When the conversation meaningfully concerns a project or topic, ALSO update the relevant note:
   - `Projects/<Name>.md` — append to `## Log`; add dated entries under `## Decisions`.
   - `Topics/` wiki — the evergreen knowledge (entities / concepts / synthesis). Update
     `Topics/index.md` when you add a page and append to `Topics/log.md`.

## Rules

- Never overwrite — append or patch. Never edit frontmatter except via `patch_frontmatter`.
- Prefer `[[wiki-links]]` to connect notes. Add `tags:` in frontmatter. Keep entries terse.
- The vault follows PARA-lite + a Memoriki-style Topics wiki. See the vault's `AGENTS.md`.
