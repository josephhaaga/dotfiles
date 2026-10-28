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
prompt segments, and tool definitions. Capture starts when the plugin loads;
there is no historical backfill. Auxiliary title, compaction, and transient
generation calls are not yet instrumented. Segment token counts are estimates.
