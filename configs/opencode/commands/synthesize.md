---
description: Synthesize recent daily logs into the evergreen Topics/ wiki (Memoriki schema)
---

You are maintaining the user's evergreen knowledge wiki in their Obsidian vault, using the
**Obsidian MCP tools** (Seekstone). Default period: the last 7 days (override if the user passed
an argument like "today" or "this month" in `$ARGUMENTS`).

## Step 1 — Gather recent activity

Use `obsidian_query_notes` (or `obsidian_list_notes`) to find recent `Daily/` notes and their
`Daily/sessions/` subfiles for the period. Read the executive summaries (the `## Summary`
section of each daily file) with `obsidian_read_note`. These are the source material.

## Step 2 — Identify durable knowledge

From those summaries, extract facts/decisions/entities that are **evergreen** (worth
remembering beyond today), not ephemeral chatter. For each, decide the wiki home per the
Memoriki schema:

- `Topics/entities/` — people, companies, products, services, repos
- `Topics/concepts/` — ideas, patterns, frameworks, architectures, decisions
- `Topics/synthesis/` — cross-cutting analysis, comparisons

Skip transient/noise (routine test runs, one-off fixes with no lasting lesson).

## Step 3 — Propose before writing

Present a concise list of proposed wiki changes (new pages + updates to existing pages) and
ask the user to confirm with the `question` tool. Do **not** write yet. This keeps you in
control of what becomes "durable knowledge" (avoids stale/duplicate/contradictory pages).

## Step 4 — Apply approved changes

For each approved item:
- Update or create the page with `obsidian_create_note` / `obsidian_patch_note` /
  `obsidian_append_note`. Append; never overwrite. Use `[[wiki-links]]` to connect pages.
- Update `Topics/index.md` to catalog any new page (`obsidian_patch_note` under the right
  section: Entities / Concepts / Synthesis).
- Append an entry to `Topics/log.md`: date, operation, pages touched.

## Step 5 — Lint (optional)

If the user asks, scan the wiki for contradictions, orphan pages (no backlinks via
`obsidian_get_backlinks`), and obvious knowledge gaps, and report them.
