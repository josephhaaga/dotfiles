# Artifact-first agent workflow

This is an opt-in design and an inert [lean global instruction example](examples/agent-workflow/AGENTS.md). Nothing here is deployed by chezmoi. The existing retirement of managed global prompts and downloaded skills remains intact.

## Ownership and adoption

Reusable skills belong in the personal [skills repository](https://github.com/josephhaaga/skills), not duplicated into dotfiles. Its proposed workflow entries are `graphify`, `slack-messages`, `goal-contract`, and explicit `whiteboard` mode. The instruction example depends on those entries: review their availability before adopting it. If a required skill is missing, resolve that prerequisite rather than assuming its instructions were applied.

The example is 31 lines instead of the reviewed deployed global prompt's 187 lines. This is an instruction-maintenance reduction, not a measured runtime token or quality improvement. The old file remains untouched. After the skill changes merge and you choose to adopt the example:

1. Review the deployed global instructions and retain any unrelated local requirements in a private backup.
2. Confirm the new skills resolve from the intended source. In OpenCode, an old `~/.config/opencode/skills/graphify` overrides the same ID linked through `~/.agents/skills`. Archive an override only after reviewing it; do not bulk-delete skill directories.
3. Deliberately install the reviewed instructions. This repository adds no automatic copy, cleanup, package installation, or migration hook.

OpenCode V2 watches configuration changes. Use its documented reload action if necessary; a service restart is for an unhealthy service or activating an upgraded executable, not routine skill edits. See [configuration](https://opencode.ai/v2/docs/config) and [instructions](https://opencode.ai/v2/docs/instructions). Other hosts may have different update behavior.

## Choose the work, process, and output independently

Keep independently useful visual formats as sibling skills. Nest their long references, not one discoverable skill inside another `SKILL.md` directory. OpenCode stops skill discovery inside a skill directory; folder nesting alone does not reduce advertised descriptions. See [skill discovery and loading](https://opencode.ai/v2/docs/skills).

| Choice | Purpose |
| --- | --- |
| Whiteboard workflow | One canonical artifact for current state, decisions, questions, and acceptance evidence |
| Design process | Scope, audience, visual hierarchy, interaction, and accessibility when relevant |
| System atlas | Preserve the explorable isometric architecture format and its generated text twin |
| HTML report/slides | Use the standalone visual-explainer renderer |
| Review surface | Bind the exact artifact to Plannotator or an already configured alternative |

Slack formatting is also conditional. Load the Slack-write skill when preparing an MCP write, not during unrelated coding or source reads. Apply the thread-headline convention to new channel topics; DMs, existing-thread replies, and explicit alternative formats remain conversational. Sending still requires the integration's approvals.

## Goal readiness before autonomy

Use the accepted spec as a contract, not a second plan the human must maintain. Give each requirement an ID, a concrete check, required evidence, and status. Before execution, resolve only missing decisions that affect safety or acceptance. Reuse approval of unchanged scope.

Verification must cover user-facing semantics as well as implementation details. For example, a topic-hierarchy requirement needs both a parent/child traversal and a visible nested representation; a passing generic test suite and an attractive graph do not establish hierarchy.

The approach draws on [Night Shift](https://jamon.dev/night-shift): invest human attention in requirements and gaps, prepare the testing plan before implementation, and use observed misses to improve docs and validations. It does not adopt implicit stashing, unrelated baseline repairs, unlimited review loops, or publishing authority.

The goal-preparation contract does not launch a goal, enable a scheduler, choose a model, or grant extra permissions. Host-specific goal/runtime settings remain separately owned. See the existing [OpenChamber workflow boundary](openchamber-workflows.md#goals-opt-in-per-task).

## Keep context when it earns its place

A long session is reasonable when subsequent work depends on its decisions. Fork when independent outcomes would benefit from separate state; compact when context pressure warrants it. Neither is a fixed-interval hygiene requirement.

[OpenCode compaction](https://opencode.ai/v2/docs/compaction) is lossy: it summarizes older history and retains a recent tail. Larger context windows increase capacity; they do not prove that a missed requirement will receive attention. A canonical acceptance ledger survives both approaches.

## Plannotator targeting and alternatives

Observed locally with Plannotator `0.27.22`: `plannotator last` opened the wrong document; opening a saved Markdown file with `plannotator annotate <absolute-path>` produced the intended review and annotations. The observation does not establish the root cause or prove the installed binary matches today's upstream.

Upstream documents OpenCode's plugin path as SDK-based and local CLI log parsers separately. [Annotate Last docs](https://github.com/backnotprop/plannotator/blob/main/apps/marketing/src/content/docs/commands/annotate-last.md) and [session discovery source](https://github.com/backnotprop/plannotator/blob/main/apps/hook/server/session-log.ts) support treating harness/session resolution as an investigation target. Do not attribute this to an agent selecting the wrong content without checking the resolved session/message identity.

For now, bind an explicit file and reuse it. A proper regression reproduction should compare the invoking session/message IDs, selected source, and rendered title/content across two sessions. Keep private transcripts out of any upstream report. This PR does not patch Plannotator or claim the defect is fixed.

[Whiteboard](https://github.com/devdotfast/whiteboard) is a promising code-linked canvas with an agent SDK, not simply another Markdown annotation viewer. Its README currently notes limited multi-repo browsing, no source-file editing in the app, and re-sharing for updates to shared reviews. No app or SDK integration is installed here.

The proposed `whiteboard` skill offers the artifact-first behavior immediately. It does not promise live reload in Plannotator or a native OpenCode mode. A host-native canvas or continuously updating viewer is a separate implementation decision requiring its actual API and lifecycle to be reviewed.

## Measure what interrupts the human

Before optimizing from token totals alone, distinguish:

- Human correction turns from added requirements and newly granted permissions.
- Integration approval round trips from unnecessary agent re-confirmations.
- Repeated skill loads within visible context from legitimate recovery after compaction.
- Unchanged failed retries from test reruns after code changes.
- Implemented work from verified, committed, pushed, and deployed work.

These are proposed profiler metrics, not telemetry implemented by this documentation change. Compare task outcomes and interruption counts after adoption; static file-size reductions alone are not a behavioral evaluation.
