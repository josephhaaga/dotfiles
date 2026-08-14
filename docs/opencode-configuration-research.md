# OpenCode Configuration Research

**Date:** 2026-08-13
**Question:** What is the ideal OpenCode configuration, and should we adopt any of five candidate agent frameworks?
**Method:** GitHub API metadata, repository source inspection, npm registry, HN/Reddit discussion, and direct measurement against this machine's installed OpenCode.

## Verdict

Adopt none of the five. Four conflict with `oh-my-openagent` (OMO), which this machine already runs; the fifth composes but is stale and thinly used.

The highest-value change is **subtracting context bloat, not adding a framework**. Measured MCP tool-description overhead dwarfs anything these frameworks add in capability.

## The five candidates

| Repo | Stars | Commits | Last commit | License | Verdict |
|---|---:|---:|---|---|---|
| [code-yeongyu/oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) | 67,834 | 12,713 | 2026-08-13 | SUL-1.0 (custom) | Already installed |
| [darrenhinde/OpenAgentsControl](https://github.com/darrenhinde/OpenAgentsControl) | 4,715 | 224 | 2026-07-14 | MIT | Conflicts with OMO |
| [kdcokenny/opencode-workspace](https://github.com/kdcokenny/opencode-workspace) | 565 | 35 | 2026-06-05 | MIT | Conflicts; needs `ocx` |
| [Cluster444/agentic](https://github.com/Cluster444/agentic) | 614 | 38 | 2025-09-02 | MIT | Stale ~11 months |
| [derekbar90/opencode-conductor](https://github.com/derekbar90/opencode-conductor) | 122 | 175 | 2026-03-02 | Apache-2.0 | Composes, but thin |

### Three tiers, not five options

**Full harnesses — pick exactly one.** OMO, OpenAgentsControl, and opencode-workspace each claim default agents, command names, and `.opencode/` namespaces. Installing two globally produces duplicate or silently overridden behaviour.

- **OMO** — TypeScript/Bun monorepo. Primary orchestrator (Sisyphus) plus specialists, lifecycle hooks, background execution, LSP/AST tooling, injected MCPs, Team Mode. Note the **custom SUL-1.0 licence**, not MIT, and **anonymous PostHog telemetry on by default** (opt-out documented).
- **OpenAgentsControl** — the philosophical opposite of OMO: approval gates and pattern control instead of autonomy and speed. Editable Markdown agents, no plugin-API runtime. Claims "80% token reduction" without a published benchmark. TypeScript/Node is the only battle-tested path.
- **opencode-workspace** — a *facade* repo synced from `kdcokenny/ocx`; no tags, no releases, no npm package, one contributor. Installs via the third-party `ocx` tool. Globally denies `webfetch` and defaults to a free-models-only profile.

**Workflow distributors.** `Cluster444/agentic` ships generic `/ticket`, `/research`, `/plan`, `/execute`, `/commit`, `/review` commands — direct collision risk with any other framework. Two contributors, no commits since 2025-09-02.

**Composable add-on.** `opencode-conductor` is the only one designed to sit *alongside* OMO ("Sisyphus Synergy" plus loop protection). But [issue #3](https://github.com/derekbar90/opencode-conductor/issues/3) documents the integration silently breaking: OMO's `AgentOverridesSchema` used a hardcoded agent whitelist that discarded `conductor` config during Zod validation. The workaround requires duplicating config across two files with different key names (`agent` singular vs `agents` plural). 218 weekly npm downloads.

## What the community found

**The benchmark that matters.** A systematic run across 120+ agent/model combinations: OMO Ultrawork scored **69.2%** pass rate against **73.1%** for plain OpenCode. It took 55 minutes versus 45, and made **96 requests versus 27**. Heavy orchestration lost on quality *and* cost.

**Cost incidents without guardrails.** [Issue #418](https://github.com/code-yeongyu/oh-my-openagent/issues/418) and related reports: 27,776 API calls in 12 minutes; $350 in 3.5 hours; 1,866 premium requests in 1.5 hours; one month's quota consumed by a single prompt. Maintainer position is that this is intended behaviour and that hard global limits will not ship by default — the harness is "intentionally designed for users who want control and are willing to configure their own limits."

**`ultrawork` is opt-in.** Without that keyword, you are running vanilla OpenCode with a substantially heavier system prompt — paying the tax without the benefit.

**Recurring community verdict.** "Everything from ohmyopencode runs fast at first, but after 2–3 tasks the tokens are gone for 4 hours." The most-quoted summary: *"I like OMO for its hooks and background task execution... The base OpenCode prompts plus background workers and hooks that auto-prompt the model to continue when it decides to stop would be enough for me."* This is what produced the `oh-my-opencode-slim` fork and migration to `oh-my-pi`.

**Structural OpenCode complaints** ([HN 48978112](https://news.ycombinator.com/item?id=48978112)) are about the harness itself, not plugins:

- `AGENTS.md` re-globbed on every SSE turn, forcing full prompt-cache misses
- Current date in the turn-0 system prompt — guaranteed cache miss at midnight
- Autocompact bugs severe enough that users run `OPENCODE_DISABLE_AUTOCOMPACT=1` permanently
- Team response: V2 (beta) reworks changing system instructions specifically to avoid cache misses

## Token overhead is the real problem

From [opencode#11995](https://github.com/anomalyco/opencode/issues/11995) and [#13188](https://github.com/anomalyco/opencode/issues/13188):

| Source | Measured cost |
|---|---|
| chrome-devtools MCP | **~17,900 tokens** |
| Built-in tool descriptions (16 files) | ~7,573 tokens |
| `bash.txt` alone | ~2,654 tokens — 63% of it git/PR instructions |
| Task tool with 150 subagents | ~6,000–10,000 tokens |
| One user's session start (60 skills) | 32,691 tokens before first message |

Critically: **tool descriptions are not cacheable**, while system prompt text is. That overhead is paid on every single API turn.

The subagent-pruning fix (`permission.task` deny/allow) is confirmed working from OpenCode v1.1.8+, but scales with subagent count — it is worth ~6-10k tokens at 150 subagents and near-nothing at 10.

## Convergent pattern

Every serious workflow — HumanLayer's Research-Plan-Implement, `agentic`, Conductor's tracks, workspace's plan protocol, OAC's approval gates — is the same idea:

> Research → Plan → Implement, with state externalised to markdown files, keeping any single session under 40–60% context.

This needs three markdown files in `~/.config/opencode/commands/`, not a framework.

## Changes applied to this repo

Source of truth is `home/dot_config/opencode/opencode.json` (chezmoi renders it to `~/.config/opencode/opencode.json`).

1. **Removed the `chrome-devtools` MCP server.** Highest-value single change at ~17.9k tokens per session. Browser debugging is occasional; re-add it project-locally in `.opencode/opencode.json` where needed.
2. **Disabled the `playwright` MCP** (`enabled: false` rather than deletion, so it is a one-word revert). Same token class as chrome-devtools.
3. **Added `permission.task` pruning** for the redundant `build` and `plan` subagents. Honest caveat: this machine exposes 10 subagents, not 150, so the saving is a few hundred tokens — directionally right, marginal in practice. The conservative denylist avoids breaking OMO's category delegation, which routes through `Sisyphus-Junior`.
4. **Dialled back `opencode-agent-profiler`.** It was running with `captureContent`, `captureHeaders`, and all four `hide*` flags off, at `maxAttrChars: 200000` — writing every prompt and every API header to world-readable `/tmp/ap-trace.log`. Now content/header capture off, `maxAttrChars: 4000`. Timing and trace data is retained.

Not changed: `agent-mcp` and `obsidian` MCP servers, and the custom `ask` agent.

### Measured result

Session-start overhead, measured on OpenCode 1.18.15 by sending a trivial prompt and reading `part.tokens` from the raw event stream:

| Configuration | Tokens before first reply | vs. bare OpenCode |
|---|---:|---:|
| `--pure` (no plugins, no MCPs) | 12,478 | baseline |
| After these changes | 52,426 | 4.2× |
| Before these changes | 66,513 | 5.3× |

**Saving: 14,087 tokens per session, a 21.2% reduction** — paid on every session, and (per opencode#11995) tool descriptions are not cacheable, so a large share recurs every turn.

The wider finding is that OMO plus the remaining MCPs still costs **39,948 tokens** over bare OpenCode — roughly 4× — which is the concrete version of the community's "bloated and overly opinionated" complaint.

Reproduce with:

```bash
cd "$(mktemp -d)"
opencode run --format json "say ok" \
  | python3 -c "import json,sys; [print(o['part']['tokens']) for o in map(json.loads, filter(str.strip, sys.stdin)) if isinstance(o.get('part'),dict) and 'tokens' in o.get('part',{})]"
```

Add `--pure` for the no-plugin floor.

**Caveat on A/B methodology.** `OPENCODE_CONFIG_CONTENT` and `OPENCODE_CONFIG` are **merge layers, not replacements** — verified on 1.18.15 by passing `{"plugin":[],"mcp":{}}` and observing that `opencode mcp list` was byte-identical to a normal run. They can *add* config but never remove it.

That makes them valid for **additive** tests only, which is what the table above measures: the "before" row was produced by merging the old config back on top, re-adding the two browser MCP servers. To measure a *subtraction*, edit the real config file and restore it afterwards, or use `--pure` for the total-plugin floor.

### Second pass

Follow-up changes made from the same research:

5. **Disabled OMO's anonymous PostHog telemetry.** Reading `shouldDisablePostHog` in the installed bundle shows three independent switches: config `telemetry: false`, `OMO_DISABLE_POSTHOG=1`, or `OMO_SEND_ANONYMOUS_TELEMETRY` set to `0`/`false`/`no`. Both a config file (`home/dot_config/opencode/oh-my-openagent.json`) and the env var are set — the config file covers every launch path, and the env var covers launches that bypass it. The redundancy is deliberate: the config file was observed disappearing once after being written, so relying on it alone is not safe. The canonical filename is used rather than the legacy `oh-my-opencode.json` to avoid triggering the plugin's config-migration copy, which would create untracked chezmoi drift.
6. **Moved the browser MCP servers into an opt-in profile.** The `opencode()` shell wrapper already selected between `work` and `personal` profiles via `OPENCODE_CONFIG`, but both were empty scaffolds. Since that variable is a *merge* layer, it is exactly the right mechanism for optional extras: the base config stays lean, and `OPENCODE_PROFILE=browser opencode` adds Playwright and Chrome DevTools when UI work needs them. This replaces the dead `"enabled": false` stub, which cost nothing but also provided nothing.

   Measured, confirming the design: `work` (default) 52,476 tokens; `browser` 66,564. The browser profile costs **+14,088 tokens**, matching the original saving to within one token — the cost is now paid only when browser tooling is actually wanted.
7. **Enabled `OPENCODE_EXPERIMENTAL_PLAN_MODE=1`** in the same wrapper. Confirmed present in the 1.18.15 binary. The default plan mode is only a preset that strips edit tools; the experimental one writes plans to markdown, which is the externalised-state half of the Research-Plan-Implement pattern above.

Considered and rejected:

- **Dynamic Context Pruning plugin** and **`OPENCODE_DISABLE_AUTOCOMPACT=1`** — adding a plugin contradicts this document's own finding that the problem is bloat, not missing capability, and disabling autocompact without a replacement degrades long sessions rather than improving them.
- **Research/plan/implement command files** — OMO already supplies Prometheus (plan builder) and Atlas (plan executor) primary agents, so these would duplicate existing routing.

### Worth keeping

The `ask` agent's `"*": "deny"` plus explicit allowlist and `/tmp/opencode-ask/**` write jail is better permission hygiene than any of the five frameworks ship by default.

Pinning `oh-my-opencode@4.19.4` rather than `@latest` is what avoided the [package rename breakage](https://github.com/code-yeongyu/oh-my-openagent/issues/2823) — the package was renamed to `oh-my-openagent` in v3.11.0 and the old name silently stopped loading for some users with no error. Verified 2026-08-13: both names are still dual-published at 4.19.4, so the pin resolves correctly. Beta line is `5.0.0-beta.7`.

## Unrelated fix made during this work

`~/.claude/settings.json` contained a malformed `Stop` hook:

```json
{ "type": "command",
  "command": "/opt/homebrew/bin/uv",
  "args": ["run", "--script", ".../claude_code_scribe.py"] }
```

Claude Code hooks take a single `command` *string*; `args` is not a schema field and was silently ignored. So bare `uv` ran, exiting **code 2** with help text on stderr. Exit code 2 is the documented "block" signal, so OMO's `executeStopHooks` fed that stderr back as an injected pseudo-user message tagged `<!-- OMO_INTERNAL_INITIATOR -->` on every session idle. The target script no longer existed either.

Not an OMO bug — OMO implemented the Claude Code hook contract correctly. Hook removed; backup at `~/.claude/settings.json.bak-20260813-211854`. Note this file is **not** chezmoi-managed.

## Sources

- [Getting more out of OpenCode](https://ricostacruz.com/posts/opencode-starter-kit) — `OPENCODE_EXPERIMENTAL_PLAN_MODE=1`, Dynamic Context Pruning, Exa
- [Oh My Opencode Review: Honest Results, Billing Risks](https://www.glukhov.org/ai-devtools/opencode/oh-my-opencode-experience/) — the 69.2% vs 73.1% benchmark
- [Research-Plan-Implement](https://www.huuhka.net/research-plan-implement/) — the convergent pattern
- [r/opencodeCLI: Does Oh-My-Opencode really provide an advantage?](https://www.reddit.com/r/opencodeCLI/comments/1q425mn/does_ohmyopencode_really_provide_an_advantage/)
- [Annoying and alarming things about OpenCode](https://news.ycombinator.com/item?id=48978112)
