---
description: Plan work for a Jira ticket, then set it In Progress and branch off
agent: plan
---

You are starting work on Jira ticket **$1**.

This command runs in **Plan mode**. Read-only steps run now; the
status change and branch creation are deferred until *after* the plan is
approved, so nothing is mutated while you are still planning.

## Step 1 — Read the ticket

Fetch the ticket with the `dev-mcp_issues_get` tool, passing
`identifier: "$1"`. If the tool is unavailable (e.g. the `dev-mcp` server is
not enabled in this environment), stop and tell the user the ticket system is
not reachable here.

Capture the ticket's **title**, **description/spec**, **status**, and any
acceptance criteria.

## Step 2 — Ask clarifying questions BEFORE planning

Tickets are often vague. Do **not** generate a plan yet. First, use the
`question` tool to resolve any ambiguity, for example:

- Unclear or missing acceptance criteria / definition of done
- Which package, service, or area of the repo is in scope
- Edge cases, non-goals, and explicitly out-of-scope work
- Whether tests/docs are expected as part of this ticket

Skip this step only if the ticket is genuinely unambiguous. If you do skip it,
say so and briefly justify why.

## Step 3 — Investigate and produce an implementation plan

Explore the current repository (the one opencode is running in) to ground the
plan in the actual code. Then produce a concrete implementation plan: the files
to change, the approach, the order of work, and how to verify it (tests,
commands). Submit it for review.

## Step 4 — Setup actions (ONLY after the plan is approved)

Do **not** run these until the user has approved the plan. These are write
actions and will prompt for approval under Plan mode — that is intentional.

1. **Verify a clean working tree.** Run `git status --porcelain`. If the output
   is non-empty, the tree is dirty: **stop** and report the uncommitted changes
   instead of switching branches. Let the user decide how to proceed.

2. **Mark the ticket In Progress.** Call `dev-mcp_issues_update` with
   `identifier: "$1"` and `status: "In Progress"`.

3. **Update the base branch and create the work branch.** Detect the repo's
   default branch dynamically — do **not** assume `master`:

   ```sh
   default_branch=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD | sed 's@^origin/@@')
   git checkout "$default_branch"
   git pull --ff-only origin "$default_branch"
   git checkout -b "$1/<slug>"
   ```

   Build `<slug>` from the ticket **title**: lowercase, spaces and punctuation
   collapsed to single hyphens, trimmed to a short, readable phrase (a few
   words). Final branch name: `$1/<slug>` (e.g. `ML-1234/add-retry-to-feed-fetch`).

Finally, confirm to the user: the ticket's new status, the base branch you
pulled, and the new branch you are now on.
