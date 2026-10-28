# OpenCode session profiling

`home/.chezmoidata/packages.yaml` pins the Agent Profiler CLI and OpenCode V2
plugin. The global OpenCode configuration sends primary agent-loop traces from
every project to `http://127.0.0.1:7070/v1/traces`. No cloud telemetry endpoint or
credentials are configured.

Open the dashboard at <http://127.0.0.1:7070/>. Run `agent-profiler status` to
check the collector. The desktop LaunchAgent and server systemd user service
keep it running across logins and process failures. Enterprise and container
profiles start the CLI daemon during apply; their environment must restart it
after reboot/container replacement (`agent-profiler start`).

Desktop service diagnostics:

```sh
launchctl print "gui/$(id -u)/com.josephhaaga.agent-profiler"
tail -n 30 ~/.local/state/agent-profiler/service.log
```

The supervised launcher uses the CLI's bundled server directly, without a
second daemon/PID file. Do not run `agent-profiler start` alongside that service.

Content capture includes prompts, source code, assistant responses, and tool
inputs/results. Authentication headers are not captured, but secrets appearing
in prompts or tool output can still be recorded. The collector binds only to
loopback and creates private runtime files. Never commit its database, logs,
or exported traces; `~/.agent-profiler/` is deliberately unmanaged.

The V2 plugin records token/cache/cost metrics, tool failures, request context,
prompt segments, and tool definitions. Live capture starts when the plugin loads.
Auxiliary title, compaction, and transient generation calls are not yet
instrumented live. Segment token counts are estimates.

## Historical import

CLI version `0.2.0` adds an explicit, read-only OpenCode V2 backfill. Dotfiles
installs the command but does not import session content automatically:

```sh
agent-profiler import opencode --session ses_...
# Or import all active and archived sessions:
agent-profiler import opencode
```

Keep OpenCode and the collector running. The command uses authenticated local
service discovery and the session export API, not direct database access.
Original OpenCode session IDs group the records. Repeated imports are safe,
and identifiable live/import overlap is deduplicated. Older collector records
without source message/tool IDs cause that session to be explicitly skipped
rather than risk double-counting.

Recorded usage, cache reads/writes, cost, and assistant tool history are retained.
Missing metrics display as Unknown, not zero. Imported history is labeled partial:
exact outgoing prompts and historical tool schemas cannot be reconstructed, and
recorded cost is not necessarily billed spend. The collector also retains the
exported-session snapshot, including synthetic/metadata messages.

Import includes unredacted saved content and does not apply the live plugin's
redaction settings. Keep imported data private, like live traces.
