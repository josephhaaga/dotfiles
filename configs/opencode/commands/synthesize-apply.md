---
description: Review today's staged wiki proposals in Plannotator, then apply approved ones to Topics/
---

You are applying **staged** knowledge-base proposals to the user's Obsidian `Topics/` wiki.
The staging file was produced by the `synthesize-day` script and lives at
`Inbox/wiki-review-<date>.md` in the vault (`SEEKSTONE_VAULT`, default
`~/Documents/obsidian-vault`). Nothing has been applied yet.

## Step 1 — Locate the staging file

Find the most recent `Inbox/wiki-review-*.md` (or the date in `$ARGUMENTS` if given) using the
Obsidian MCP tools (`obsidian_list_notes` / `obsidian_read_note`). If none exists, tell the user
to run `synthesize-day` first and stop.

## Step 2 — Open it in Plannotator for review

Run the annotate skill on the ABSOLUTE path of the staging file so the user can review,
correct, approve, or reject each `## PROPOSAL` in Plannotator's UI. Resolve the vault root from
`$SEEKSTONE_VAULT` (default `$HOME/Documents/obsidian-vault`):

```bash
plannotator annotate "$HOME/Documents/obsidian-vault/Inbox/wiki-review-<date>.md"
```

Wait for the browser review to finish. Plannotator returns annotations (edits, approvals,
rejections, comments). If the session closes with no feedback, ask the user whether to apply all
proposals as-is or abort.

## Step 3 — Apply approved proposals

Honor the user's annotations. For each proposal the user KEPT/approved (with any edits they made):

- Create or append the target `Topics/<...>.md` page via `obsidian_create_note` /
  `obsidian_append_note` / `obsidian_patch_note`. Append; never overwrite existing content.
- Preserve `[[wiki-links]]`. Add frontmatter (`type`, `tags`) on new pages.
- Update `Topics/index.md`: catalog each new page under its section (Entities/Concepts/Synthesis).
- Append one line per applied change to `Topics/log.md`: date, `apply`, pages touched.

Skip any proposal the user rejected or deleted. Apply their inline edits verbatim.

## Step 4 — Clean up + report

- Move the processed staging file to `Inbox/applied/wiki-review-<date>.md` (via
  `obsidian_move_note`) so it isn't reprocessed, or delete it if the user prefers.
- Report a concise summary: which pages were created/updated, and which proposals were skipped.
