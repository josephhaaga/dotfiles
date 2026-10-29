# OpenCode Multiplayer

`opencode-multiplayer` is a collaborative-session plugin for OpenCode V2. It
lets several people—and later a voice-driven meeting participant—work from one
task session, make competing proposals, vote, and fork an option into an
independent OpenCode child session.

It is deliberately **not** a new agent runtime. Every action runs through a
normal OpenCode session and therefore retains that session's selected agent,
model, workspace, configured MCP servers, tools, and permissions.

## Package identity and surfaces

Use the standard OpenCode package pattern shown in the V2 plugin docs:

```text
npm package: opencode-multiplayer
server plugin ID: multiplayer
tool/RPC namespace: multiplayer
```

Ship one package with these exports:

```json
{
  "name": "opencode-multiplayer",
  "type": "module",
  "exports": {
    ".": "./dist/index.js",
    "./rpc": "./dist/rpc.js",
    "./tui": "./dist/tui.js",
    "./gui-experimental": "./dist/gui-experimental.cjs"
  }
}
```

| Part | Responsibility |
| --- | --- |
| Server | Room state, contribution admission, proposal/poll state, fork orchestration, and typed RPC. |
| TUI | Commands and a compact status/poll view for terminal users. |
| Desktop GUI | Session panel, notifications, poll dialogs, and the future macOS meeting-input adapter. |
| RPC | The typed contract between the server, TUI, Desktop GUI, and any trusted external client. |

The server part is the product core. It works wherever that OpenCode server is
used. The current GUI plugin API is explicitly experimental and documented as
an OpenCode Desktop integration. Do not promise a custom Web UI until the
installed OpenCode version documents and loads that surface; Web users can use
the shared session and server events without a custom Multiplayer panel.

Load the package through `plugins` in `opencode.json(c)`. The Desktop GUI part
must be loaded from global `opencode.json(c)`, rather than only `cli.json`.

## Product model

### Room

A **room** is collaboration metadata bound to one existing root OpenCode
session. It is not a replacement for the session or a copied transcript.

```ts
type Room = {
  id: string
  rootSessionID: string
  directory: string
  ownerID: string
  status: "active" | "paused" | "closed"
  revision: number
  createdAt: string
}
```

Persist the binding in both supported OpenCode stores:

- A keyed session instruction entry, `multiplayer.room`, containing the room
  ID, role, and concise active-decision context. This lets the selected agent
  see the collaboration context after compaction and restart.
- Plugin storage for room membership, contributions, proposals, votes, and
  fork lineage.

Never write OpenCode's internal session database or retain a second copy of a
session transcript.

### Participants and contributions

A participant is an authenticated OpenCode user/client attached to the same
server. The plugin displays the identity supplied by the authenticated client
or its configured display name; it must not invent identity from a free-form
prompt.

```ts
type ParticipantRole = "owner" | "facilitator" | "member" | "observer" | "agent"
type ContributionKind = "steer" | "queue" | "comment" | "proposal" | "meeting-command"

type Contribution = {
  id: string
  roomID: string
  authorID: string
  kind: ContributionKind
  text: string
  createdAt: string
  sessionMessageID?: string
}
```

Contribution delivery rules are fixed:

| Kind | OpenCode behavior |
| --- | --- |
| `steer` | Submit as `session.prompt` with delivery `steer`; it redirects the in-progress turn. |
| `queue` | Submit as `session.prompt` with delivery `queue`; it waits behind existing work. |
| `comment` | Save to room activity only. It does not enter model context or trigger work. |
| `proposal` | Create a proposal. It enters model context only when adopted. |
| `meeting-command` | Same as `steer` or `queue`, selected by the meeting-input adapter's explicit intent. |

Do not turn ordinary meeting audio or every room comment into agent context.

### Proposals and polls

Use a proposal when there are multiple credible paths. A poll makes disagreement
visible; it does not make an irreversible tool action autonomous.

```ts
type Proposal = {
  id: string
  roomID: string
  title: string
  options: Array<{ id: string; label: string; evidence: string[] }>
  state: "draft" | "open" | "resolved" | "superseded"
  createdBy: string
  adoptedOptionID?: string
  revision: number
}

type Vote = { proposalID: string; optionID: string; voterID: string; createdAt: string }
```

Rules:

1. A participant may change their own vote while the poll is open; only the
   latest vote counts.
2. The UI displays counts and voter names when the room's privacy setting
   permits them. The default is named, not falsely anonymous.
3. The owner or a facilitator resolves a poll. A plurality is advisory, not an
   automatic choice.
4. Resolving and adopting an option emits one concise queued/steering message
   to the root session with the selected option and recorded evidence.
5. Closing a poll without adoption leaves the parent session unchanged.

### Forks and autonomous work

Forks explore options without contaminating the parent session's task history.

```ts
type Fork = {
  id: string
  roomID: string
  proposalID?: string
  optionID?: string
  parentSessionID: string
  childSessionID: string
  goal: string
  status: "queued" | "running" | "waiting" | "completed" | "failed" | "stopped"
  createdBy: string
}
```

Create child sessions with OpenCode's native session-fork API. The plugin stores
lineage and room metadata; OpenCode remains the source of truth for message
history and the fork boundary.

Each fork receives one explicit initial goal prompt, for example:

> Explore option B. Produce an implementation, update the linked Whiteboard
> only if necessary, and return trade-offs, changed artifacts, and unresolved
> risks. Do not merge or deploy.

The fork may use the child session's inherited tools and permissions, but it
must not be treated as unattended permission bypass. When OpenCode asks for a
permission or form response, mark the fork `waiting` and surface that state to
room participants. Owner/facilitator actions are required to resume, stop, or
adopt a fork's output.

On completion, create a structured comparison record in the parent room:

```ts
type ForkResult = {
  forkID: string
  summary: string
  artifacts: Array<{ type: "file" | "board" | "url" | "session"; ref: string }>
  tradeoffs: string[]
  risks: string[]
  followUpPrompt: string
}
```

Do not automatically merge files, overwrite a Whiteboard, or inject a child
result into the parent conversation. An explicit **Adopt result** action sends
the result's `followUpPrompt` to the root session.

## Interaction design

### Session panel

The Desktop panel is the primary graphical surface. It has four compact areas:

1. **Room:** participants, connection state, active agent/session, and pause/end
   controls.
2. **Contributions:** steer, queue, comment, and proposal composer with visible
   delivery mode.
3. **Decision:** open polls, vote controls, evidence, and adopt/close actions.
4. **Forks:** goals, execution/permission state, links to child sessions, and
   result adoption.

The TUI exposes the same operations through commands and a focused panel; it
does not need to duplicate the graphical poll treatment.

### Meeting Participant input (later phase)

Meeting Participant Mode is an optional Desktop input adapter, not a second
scribe product. It may use local speech recognition or a multimodal provider
such as Gemini Live for wake detection, command transcription, and optional
screen grounding.

- Start it explicitly for one room/session.
- Submit only an addressed command (wake phrase or push-to-talk) as a
  `meeting-command` contribution.
- Attach a current screenshot only when the speaker requests screen context.
- Stay silent by default; progress belongs in OpenCode's timeline and the
  Multiplayer status UI.
- Keep no durable meeting transcript. Granola, Whisperflow, or another meeting
  product remains the durable meeting record.

Examples:

- “Atlas, queue research on the two auth approaches.”
- “Atlas, make a poll for these options.”
- “Atlas, fork option B and have it implement the diagram.”

The adapter must never stream ordinary meeting speech continuously into an
OpenCode session.

## Server/RPC contract

Define the contract in `src/rpc.ts` with JSON Schema or Standard Schema. Keep
the following methods separate so all surfaces use exactly the same server-side
rules:

```ts
createRoom({ sessionID }): Room
joinRoom({ roomID }): { room: Room; participant: Participant }
submitContribution({ roomID, kind, text, delivery? }): Contribution
createProposal({ roomID, title, options }): Proposal
vote({ proposalID, optionID }): Proposal
resolveProposal({ proposalID, action: "adopt" | "close", optionID? }): Proposal
forkOption({ roomID, proposalID?, optionID?, goal }): Fork
stopFork({ forkID }): Fork
adoptForkResult({ forkID }): Contribution
getRoom({ roomID }): RoomSnapshot
```

Emit typed events for `room.updated`, `contribution.created`,
`proposal.updated`, `fork.updated`, and `fork.result`. Events are live-only in
OpenCode, so every client must call `getRoom` after connecting or reconnecting.

The server is the only component allowed to mutate room state or call
`session.prompt`/native session fork. UI clients request actions over RPC.

## Concurrency, safety, and trust boundary

- Serialize mutations per room and increment `revision` on every accepted
  change. Reject stale proposal-resolution requests with the latest snapshot.
- Deduplicate retried contribution submissions with a client-generated request
  ID persisted alongside the resulting OpenCode inbox/message ID.
- Render pending OpenCode permissions and forms. Never answer them on behalf of
  a human participant.
- A room is collaboration metadata, not a security boundary. Any user who can
  directly access the shared OpenCode server and its session can bypass the
  plugin UI. Public links and unauthenticated writes are out of scope.
- Store no OAuth credentials, audio recordings, screen recordings, session
  databases, or copied message histories in the plugin.
- Treat Whiteboard as an ordinary configured MCP/tool. Its existing task/board
  binding rules still apply; Multiplayer must not bypass them.

## Delivery plan

### Milestone 1: shared-session MVP

1. Implement server RPC, room persistence, and events.
2. Bind a room to an existing session and submit `steer`, `queue`, and comment
   contributions.
3. Add TUI commands and a Desktop status/panel view.
4. Add a two-option proposal and named voting.

**Acceptance test:** two authenticated clients attached to one OpenCode server
can join one room; one steers a running task, another queues follow-up work, and
both see the same proposal/vote state after reconnecting.

### Milestone 2: forked deliberation

1. Create an OpenCode-native child session from a proposal option.
2. Submit its explicit goal and surface tool/permission lifecycle state.
3. Persist lineage and return a structured result to the room.
4. Require an explicit parent-session adoption action.

**Acceptance test:** a fork can independently research or modify its workspace,
then a collaborator opens the child session and the owner chooses whether to
send its result back to the parent.

### Milestone 3: meeting participant adapter

1. Add explicit start/stop controls and push-to-talk command ingress.
2. Submit recognized commands through the same `submitContribution` RPC.
3. Add wake-word and on-demand screenshot context only after the push-to-talk
   path is reliable.

**Acceptance test:** during a real meeting, an addressed command creates a
proposal, starts a fork, or steers a Whiteboard/code task without ordinary
meeting audio entering the OpenCode session.

## Verification

Write deterministic tests around the server part before testing UI surfaces:

- Contribution delivery maps correctly to `steer`, `queue`, or no session input.
- A comment or unaddressed meeting transcript cannot prompt the model.
- Vote replacement, resolution authorization, stale-revision rejection, and
  reconnect snapshots are correct.
- Fork lifecycle pauses on permission/form requests and never auto-adopts work.
- Room metadata survives plugin/server restart without duplicating session
  history.
- Two rooms cannot read or mutate each other's proposal/fork state.

Run an isolated live-server test with fixture agents and a fixture MCP before
testing against a real Whiteboard or provider account. Keep all fixture
sessions, storage, and logs in a temporary XDG/HOME directory.

## References

- [OpenCode V2 plugins](https://opencode.ai/v2/docs/build/plugins)
- [Server plugins](https://opencode.ai/v2/docs/build/plugins/server)
- [Plugin RPC](https://opencode.ai/v2/docs/build/plugins/rpc)
- [Desktop GUI plugins](https://opencode.ai/v2/docs/build/plugins/gui)
- [OpenCode client](https://opencode.ai/v2/docs/build/client)
- [OpenCode API](https://opencode.ai/v2/docs/api)
