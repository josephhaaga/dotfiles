# Whiteboard

The macOS desktop package inventory includes `devdotfast/tap/whiteboard`.
The publisher's third-party Homebrew tap executes cask code; it is retained
specifically for Whiteboard. Enterprise, server, and container profiles do not
enable its OpenCode MCP server.

## Finish setup on a new Mac

1. Install the managed Brewfile, or run `brew install --cask devdotfast/tap/whiteboard`.
2. Open Whiteboard and install its CLI from **Settings → Command line** (also offered during welcome setup).
3. Confirm `~/.local/bin/whiteboard version` works.
4. Run `opencode mcp list` and confirm `whiteboard` connects. Use `/reload` in an existing OpenCode session if needed.

Dotfiles configure the desktop MCP server to run `~/.local/bin/whiteboard mcp`.
Whiteboard owns its CLI launcher and local runtime state; chezmoi manages
package selection, OpenCode registration, and the opt-in mode below. No hosted login,
trace capture, or cloud storage configuration is required by this setup.

## Use Whiteboard mode

After reviewing and applying the desktop chezmoi source:

1. Start Whiteboard yourself. Confirm its MCP is connected in OpenCode's `/mcps`.
2. Run `/whiteboard Build a project plan for …`, or select the **whiteboard** primary agent in OpenCode's agent picker.
3. Leave the created board open. Substantive answers and follow-up revisions go there; OpenCode holds short status messages and the board link.
4. Edit the board, then resume the same OpenCode session with `Read the board feedback and continue`.

`/whiteboard` selects the primary agent for the current session; it is not a
one-shot subagent. Select **build** or **plan** to leave the mode. No default
agent or model is overridden. A new independent task needs a new OpenCode
session. Routine config changes reload automatically; use `/reload` if needed.

This mode is **board-first output, not a replacement chat client**. The installed
Whiteboard 0.4.0 MCP supports incremental saved edits and activity updates, but
exposes no verified comment subscription or notification that wakes the
originating OpenCode session. Board edits are read on explicit continuation;
native thread/comment delivery is not established. The mode reports this limit
instead of claiming an always-listening feedback bridge.

## Ownership and identity

The environment wiring is deliberately small:

```text
/whiteboard <request> → primary agent whiteboard
  whiteboard_context → actual invoking OpenCode session + saved binding
  Whiteboard MCP     → status, guidance, create/read/edit, activity
  whiteboard_bind    → durable session instruction entry + board claim
```

The V2 plugin's tool context supplies the session ID; the model cannot choose
another session as a tool argument. The immutable binding records the exact
board ID, instance key, and location directory in the session's
`dotfiles.whiteboard` instruction entry. OpenCode persists and reinjects this
entry across turns, compaction, and host restarts. Plugin storage claims a board
for its session, so two tasks cannot bind the same board accidentally.

The plugin checks board-targeted MCP calls from the Whiteboard agent before
execution. An already-bound task cannot create a replacement board or read/edit
a different board. Before binding it can inspect an explicitly supplied board,
but cannot author it. Parallel binding attempts are serialized within one host;
idempotent retries preserve the winner. Claims are made before instruction
writes so an interrupted bind remains recoverable by its original session.

These checks are task-isolation guardrails, not a security sandbox. Other
agents, manually invoked CLI commands, and independent OpenCode server processes
are outside the guard's scope. Use the ordinary shared host for collaborating
tasks. Do not use two independent hosts to claim the same board concurrently.

The primary agent supplies OpenCode-specific routing and recovery instructions;
Whiteboard MCP supplies current authoring guidance and component schemas. This
does not duplicate the portable whiteboard skill proposed in
[skills PR #2](https://github.com/josephhaaga/skills/pull/2), or replace
system-atlas. With an existing canonical file/data model, the board is a linked
discussion view; authorized changes belong in that canonical source first.

## Surface choice

The available surfaces have different boundaries:

| Surface | Identity and refresh | Feedback boundary |
| --- | --- | --- |
| Whiteboard MCP — chosen | Exact board ID; saved incremental edits update the same board. | Read board edits on resume; automatic comment-to-session delivery is unverified. |
| `plannotator annotate <absolute-path>` | Exact canonical file; explicitly reopen it for review. | Explicit review/annotation round trip, not a verified persistent live canvas. Avoid ambiguous `last` selection ([#76](https://github.com/josephhaaga/dotfiles/issues/76)). |
| OpenCode native document surface | No editable native canvas verified in the V2 agent/config APIs evaluated here. | Do not assume GUI/plugin renderers supply a task-bound collaboration surface. |

No new adapter, cloud account, watcher, or background feedback poller is added.
Desktop-only deployment leaves enterprise/server/container profiles unchanged.
The plugin registers tools without starting an app, contacting MCP, or writing
bindings at startup. Binding and board authoring begin only after mode selection.
Source control contains no sessions, claims, credentials, or viewer databases.

## Recover a task

1. Restart Whiteboard yourself and reconnect its MCP via `/mcps` if disconnected.
2. Resume the original OpenCode session and select **whiteboard** again if necessary.
3. Ask it to continue. It reads `whiteboard_context`, verifies the instance key, and reads/reopens the exact saved board before editing.

A missing board, inherited binding in a forked session, changed location, or
wrong instance fails closed. It does not search by title, select a recent board,
or erase the saved mapping. Resume the original location/session; start a new
task session for a genuinely new board. Activity IDs can expire and are not
durable task identity. Binding state lives in OpenCode's supported instruction
entry and plugin-storage APIs, not direct database or filesystem manipulation.

## Verification

Run deterministic tests without starting hosts:

```sh
bash scripts/test-whiteboard.sh
bash scripts/validate.sh
```

The tests cover profile routing, inert registration, exact context identity,
idempotent binding, parallel task isolation, wrong-board MCP calls, fork/move
rejection, and recovery after a failed write or recreated plugin context.

With explicit consent, the live integration test starts isolated loopback hosts
with synthetic data and a deterministic local OpenAI-compatible fixture model:

```sh
python3 tests/whiteboard-live.py --allow-isolated-servers
```

It exercises the installed OpenCode V2 plugin loader, real tool dispatch,
Whiteboard MCP edits, explicit-resume feedback, and restarts of both hosts.
It uses temporary HOME/XDG/database/Whiteboard state, no provider accounts, and
no personal boards. It stops its own processes and retains the printed synthetic
fixture/log directory for inspection. It does not evaluate model judgment or
prove that native comments wake a session.

Verified on 2026-10-28 with OpenCode 2.2.0 and Whiteboard 0.4.0:

```text
PASS /whiteboard primary-agent routing, V2 plugin loading, and two session bindings
PASS three live MCP edits, cross-board rejection, explicit-resume feedback round trip
PASS real OpenCode + Whiteboard host restart preserves bindings and board content
Isolated servers stopped; no global config or personal boards modified.
```

The live run uses MCP Code Mode, including its nested-tool error metadata. The
two identity tools remain directly exposed so a model can establish its task
context before discovering authoring tools. The deterministic fixture tests
dispatch and persistence, not an LLM's compliance with the authoring prompt.

For a human-visible walkthrough, leave the task's board open and do this:

1. Request a report, then a diagram, then an acceptance checklist in one `/whiteboard` session. Confirm the same board ID after all three requests.
2. Change a sentence directly on that board. Resume the original OpenCode session and confirm the agent incorporates it without overwriting unrelated user text.
3. Open a second task session. Confirm it has a different board and cannot bind/edit the first task's board.
4. Restart the viewer, reconnect MCP, and resume the first session. Confirm the exact board, decisions, and checklist remain.

Live host tests and this visual walkthrough have separate evidence: an API
round trip alone does not establish user-visible refresh behavior or native
comment routing. Keep [#78](https://github.com/josephhaaga/dotfiles/issues/78)
open until the human-visible workflow meets its acceptance criteria.

## API references

This wiring targets the pinned OpenCode 2.2.0 runtime:

- [V2 agents](https://opencode.ai/v2/docs/agents) and [commands](https://opencode.ai/v2/docs/commands).
- [V2 server plugins](https://opencode.ai/v2/docs/build/plugins/server): tool contexts/hooks, session instruction entries, and plugin storage.
- The published `@opencode/plugin@2.2.0` Plugin interface is `{id, setup}`; `Plugin.define` returns that object unchanged. This dependency-free local plugin implements that interface directly.
- [Whiteboard source](https://github.com/devdotfast/whiteboard), with the installed MCP catalog as the authority for available tool names and schemas.
