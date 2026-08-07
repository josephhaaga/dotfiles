# Agent Instructions

Personal agent instructions are managed through chezmoi and use one canonical
global source. Project instructions are committed with each project.

## Global Instructions

`home/dot_config/opencode/AGENTS.md.tmpl` deploys to
`~/.config/opencode/AGENTS.md`. It is the canonical source for personal
instructions that apply in every repository.

The Slack guidance in this file is rendered only when chezmoi's `work` data
value is `true`; personal-machine deployments omit it. Guidance not inside the
template conditional applies on every machine.

OpenCode discovers that file as its native global rules file. Do not add it to
the `instructions` array in `opencode.json`.

`home/dot_claude/CLAUDE.md` deploys to `~/.claude/CLAUDE.md` and contains only
an import of `~/.config/opencode/AGENTS.md`. Claude Code expands that import,
so it receives the same global guidance without a copied second version.

Edit the canonical source, not either deployed target:

```sh
chezmoi edit --apply ~/.config/opencode/AGENTS.md
```

Alternatively, edit the source directly at
`home/dot_config/opencode/AGENTS.md.tmpl`, inspect `chezmoi diff`, and run
`chezmoi apply`.

## Project Instructions

Each repository should commit `AGENTS.md` as its shared project-level source.
It contains project-specific commands, conventions, architecture decisions,
and operational constraints. Both OpenCode and other agents can consume it.

Add a minimal `CLAUDE.md` beside it for Claude Code:

```markdown
@AGENTS.md
```

Claude-specific instructions, when genuinely necessary, go below the import.
Do not repeat shared project rules in both files. OpenCode selects the project
`AGENTS.md` instead of the project `CLAUDE.md`, preventing duplicate loading.

Global personal instructions provide the broad baseline. Project `AGENTS.md`
is the narrower layer for that repository and must not contradict the global
guidance unless the project requirement deliberately needs to take precedence.

## Migration

For a repository that already has `CLAUDE.md`:

1. Move rules shared by all coding agents into a committed `AGENTS.md`.
2. Replace the shared portion of `CLAUDE.md` with `@AGENTS.md`.
3. Retain only Claude Code-specific guidance below that import.
4. Remove duplicate instructions and resolve contradictions before committing.

For a repository with no instructions, create `AGENTS.md` first, then add the
one-line `CLAUDE.md` adapter.

## Verification

Run `bash scripts/validate.sh` before committing dotfile changes. Preview and
deploy instruction updates with `chezmoi diff` and `chezmoi apply`.

Start a new OpenCode session after updating OpenCode configuration or global
instructions; OpenCode reads them at startup. In a new Claude Code session,
run `/context` to confirm that `~/.claude/CLAUDE.md` loaded and its import is
present.
