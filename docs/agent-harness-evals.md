# How Agent Harness Developers Evaluate and Iterate

Research into how the teams behind VS Code Copilot, OpenCode, Claude Code, and oh-my-pi evaluate
and iterate on their agent harnesses — covering evals infrastructure, prompt iteration patterns,
and benchmarking approaches.

---

## VS Code Copilot — Most Sophisticated

The most mature eval setup of the four. They have a **full automated CI pipeline** triggered by a
`~requires-eval-assessment` PR label:

- PR gets labeled → ADO build triggered → benchmark runs against `vscbench`, `swebench`, `terminalbench2`
- Results posted back as a bot comment with quantitative data (e.g. "Δ = −5.1%, 95% CI [−45%, +35%], not significant at n=10 seeds")
- PRs can be reverted or drafted based on eval outcomes — this actually happened on [PR #316500](https://github.com/microsoft/vscode/pull/316500)
- Infrastructure is in private repos (`vscode-engineering`, `evald`), but the workflow is visible in public PR comments
- Tests multiple models per run (gpt-5.4, claude-opus-4.x simultaneously)

**Key reference:** 52+ PRs with `~requires-eval-assessment` label in `microsoft/vscode`.

---

## Anthropic / Claude Code — Rigorous but Opaque

- External benchmark: **SWE-bench Verified** on GKE, with a [published scaffold](https://www.anthropic.com/engineering/swe-bench-sonnet) (Bash tool + str_replace_editor, 5-step system prompt)
- Internal evals for specific behaviors: **concision**, **file edit quality**, **over-engineering** — not public
- They layer evals + production monitoring + A/B tests + user feedback
- Published postmortems when production quality regressed
- Discovered their model exhibiting **eval awareness** (gaming benchmarks) on BrowseComp

**Key references:**
- [SWE-bench Sonnet](https://www.anthropic.com/engineering/swe-bench-sonnet)
- [Demystifying Evals for AI Agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
- [Infrastructure Noise](https://www.anthropic.com/engineering/infrastructure-noise)
- [Eval Awareness / BrowseComp](https://www.anthropic.com/engineering/eval-awareness-browsecomp)

---

## OpenCode — No Formal Evals

- Pure **ship and observe** loop: users file issues, contributors fix prompts, small atomic commits
- Prompt changes tracked in git history (commit messages like `fix(prompt): better summary prompt`)
- The repo **dog-foods itself** — OpenCode runs on the OpenCode repo as a live test environment
- One notable infra PR: adding `OPENCODE_DATE` env var to stabilize system prompts for deterministic CI replay
- No eval directory, no CI benchmark jobs

Prompt files live in `packages/opencode/src/agent/prompt/` (compaction, summary, title, explore, scout)
and are assembled dynamically in `packages/opencode/src/session/prompt.ts`.

---

## oh-my-pi — Harness-Focused Benchmarking

- Developer published a blog post specifically on [the harness problem](https://blog.can.ac/2026/02/12/the-harness-problem/) — measuring how much the *tool harness* affects model performance vs. the model itself
- Tracks per-model edit success rates and pass rates (e.g. "Grok Code Fast: 6.7% → 68.3% tenfold lift")
- Most directly relevant to the question of harness iteration vs. model iteration

**Repo:** [can1357/oh-my-pi](https://github.com/can1357/oh-my-pi)

---

## Summary

| Team | Approach | Tooling |
|---|---|---|
| VS Code Copilot | Eval-gated merges, quantitative CI | Private `evald` system, `vscbench`/`swebench`/`terminalbench2` |
| Anthropic | SWE-bench + internal behavioral evals | GKE, internal harness |
| OpenCode | Ship + observe, git history | None |
| oh-my-pi | Harness benchmarking | Custom per-model metrics |

The sophistication scales with team size and commercial stakes. The common thread at the high end is
**task-completion benchmarks** (SWE-bench or custom suites) run against real coding tasks — not unit
tests of prompts. OpenCode is the most "indie" and does essentially what most solo developers do:
ship, watch issues, fix.

---

*Researched May 2026.*
