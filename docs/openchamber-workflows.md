# Native OpenChamber Workflows

Run the offline preview from the repository first:

```bash
python3 home/dot_local/bin/executable_openchamber-workflows \
  --defaults home/dot_config/dotfiles/openchamber-workflow-defaults.json --dry-run
```

This change uses native OpenChamber features, not a custom extension or a Linear-label dispatcher. It does not install, enable, or modify the abandoned prototype.

## Ownership and defaults

All four profiles copy a dotfiles-owned overlay to `~/.config/dotfiles/openchamber-workflow-defaults.json` and a manual helper to `~/.local/bin/openchamber-workflows`. Copying these files does **not** apply OpenChamber settings. No chezmoi hook calls the helper. Existing bootstrap service hooks are unchanged; do not run a full apply just to test these workflows.

The overlay contains only these workflow preferences:

- Work tracking and auto-open, recaps, and suggested next messages are enabled.
- Native notifications are enabled when the app is hidden, for questions, errors, and completion; subtask notifications are off.
- New sessions default to `ask`, not automatic permission acceptance. Existing session-specific permission choices are untouched.
- Goal automation is disabled. A 20,000-token default budget is enabled for later opt-in, with one automatic continuation allowed.

Recaps/suggestions can invoke the **already configured** small model and incur usage. Work auto-open can invoke an **already configured** classifier. These are assist features, not autonomous task execution. The overlay does not select a model, provider, checker, or Jev endpoint, add credentials, or change provider policy. For zero background model usage, set recap, suggestion, and work auto-open to `false` in the overlay before applying it.

Nothing under `~/.config/openchamber` is source-managed. Settings, timestamped preferences, OAuth, Linear mappings, runtime project files, sessions, pairing credentials, schedules, and caches remain application-owned. Only allowlisted changed workflow fields are sent; the helper never sends the full settings document back to the server or saves it to a backup/log. OpenChamber may itself migrate unrelated legacy state during API reads/writes.

## Check the internal contract before applying

### OpenCode configuration boundary

Dotfiles no longer ships global OpenCode `AGENTS.md`, downloaded skills, skill-dependent slash commands, or Plannotator's plugin/commands/installer. The repository's root `AGENTS.md` remains: it governs development of dotfiles, not every coding session.

OpenCode configuration is pared down to avoid competing workflow ownership:

- Global model and title-agent overrides are removed so the app/session can choose them.
- The custom `context-researcher` agent and restrictions on built-in `build`/`plan` subagents are removed. Connected-work MCP tools can be used directly with an `ask` approval instead of a forced delegation path.
- Dotfiles declares no plugins. This does not disable OpenChamber's separately managed native plugins or repository-local plugins.
- Existing MCP endpoints, OAuth configuration, shell settings, and provider policy remain. Enterprise still permits only GitHub Copilot and its reviewed MCP servers.

This is a **source-only retirement**, not deletion from deployed machines. Removing files from the chezmoi source does not remove previously deployed global instructions, skills, or commands, and removing a package pin does not uninstall an existing package. Before a later deployment, inspect and archive/remove only the retired files you intend to stop loading; preserve credentials and unrelated local customizations. No automatic cleanup script is added. After deliberately deploying the OpenCode changes and retiring leftover files, restart OpenCode to load them; this PR does neither. Other ancestor/project configuration can still override global defaults.

### Version checks

The supported package is currently `@openchamber/web` **2.2.0**, matching the server package pin in `home/.chezmoidata/packages.yaml`. The workflow contract is reviewed for **2.1.1** and **2.2.0**. `/api/version` and GET/PUT `/api/config/settings` are internal, version-dependent APIs, **not a stable public contract**. Desktop releases can differ from the pinned server package; an unreviewed version fails closed.

1. Run the offline unit and mock HTTP tests:

   ```bash
   PYTHONDONTWRITEBYTECODE=1 python3 scripts/test-openchamber-workflows.py
   ```

2. Probe a reviewed installed package directory without calling the running service:

   ```bash
   node scripts/check-openchamber-contract.mjs \
     --package-dir "$(npm root -g)/@openchamber/web"
   ```

3. For a candidate package version, point at an already unpacked, reviewed package:

   ```bash
   node scripts/check-openchamber-contract.mjs \
     --package-dir /path/to/reviewed/package --expected-version VERSION
   ```

The contract probe imports code from the supplied package: only use a trusted installation or artifact. It uses an in-memory filesystem, invokes the package's real settings handlers/sanitizer/persistence, checks preservation and preference timestamps, and checks the version endpoint source signature. It never reads the real OpenChamber data directory, authenticates, starts a service, or sends HTTP requests. It is not a live authentication/mTLS integration test. A candidate pass does not authorize that version: review the implementation, then update both the overlay's `openchamberVersions` and the helper's `SUPPORTED_VERSIONS` in a PR. The shared validation also checks the package pin remains reviewed.

Verified implementation files under the package's `server/lib/opencode/` are `routes.js`, `core-routes.js`, `settings-registry.json`, `settings-helpers.js`, `settings-runtime.js`, and `settings-files.js`. PUT sanitizes and merges a partial body. Instance fields go to `settings.json`; profile fields go to version-1 `preferences.json` entries with `value` and `updatedAt`, with a legacy base copy in `settings.json`. The helper uses the base view, not a device/surface override.

## Explicit apply and verify (manual)

Use the helper from the repository until you choose to deploy it. Its offline dry-run is the only mode that makes **no server requests**. With `--url`, dry-run and verify perform GETs, which can trigger OpenChamber's own migrations. `--apply` alone permits PUT. Exit codes are 0 for success, 1 for verification drift, and 2 for errors.

1. Open the **intended OpenChamber instance** and sign in manually. Choose its exact origin (scheme, host, port), not an OpenCode endpoint. Use existing approved HTTPS access, or an SSH tunnel to loopback; do not expose the server or change firewall/TLS policy for this setup.
2. Run the authenticated preview. Paste that instance's current **Cookie request header** from the browser's developer tools into the hidden prompt; do not paste it into chat, a command line, or this repository. Cookie names may include the instance port. No login or OAuth flow is performed by the script.

   ```bash
   python3 home/dot_local/bin/executable_openchamber-workflows \
     --defaults home/dot_config/dotfiles/openchamber-workflow-defaults.json \
     --url https://YOUR-APP-HOST --dry-run
   ```

3. Review the displayed desired changes, then repeat the same command with `--apply` instead of `--dry-run`.
4. Repeat with `--verify`. A second apply sends no PUT when the desired values already match.

For existing mTLS access, supply `--client-cert /local/cert.pem --client-key /local/key.pem` and, if needed, `--ca /local/ca.pem`. The helper always verifies TLS, refuses all redirects, disables ambient HTTP proxies, and permits plaintext only on loopback. It discovers no endpoints and reads no existing credential stores. Certificate/key files remain unmanaged. A desktop connected to a remote VM should target the VM instance holding that project's state, not accidentally apply the same overlay to its local instance.

Noninteractive use requires a **local, user-owned mode-600** `--auth-file` outside the repository, containing a JSON object with `origin` equal to the exact `--url` origin (without trailing slash) and `cookie` equal to the Cookie header. Do not include other credentials. The helper never creates this file. Remove it when no longer needed; its cookie expires or can be revoked via the app. Authentication failures report only an HTTP status, never response bodies or cookies. No unauthenticated fallback, automatic restart, or automatic rollback is attempted.

## Manual checklist: integrations and trust

Complete these in the app, not through dotfiles:

1. **Linear on the VM:** Settings → Integrations → Linear → Connect; complete OAuth in the browser. Select the correct workspace and map the default/per-team projects to directories **on the VM**. Tokens and mappings stay runtime-local.
2. **Notifications on the laptop:** grant OpenChamber/browser notification permission in the OS and browser, check Focus/Do Not Disturb, and test a question/completion while the app is hidden. VM settings cannot grant laptop OS permission.
3. **Repository command trust:** inspect `.openchamber/project.json` and any project loops before approving them in OpenChamber. Worktree setup/actions are shell commands. Trust must be local and explicit; dotfiles do not preapprove commands or rewrite existing project configuration.
4. **Optional Jev:** choose/configure it only after approving the outbound data policy. Classification and goal auditing send conversation excerpts outside the server. Work auto-open depends on a usable classifier; goal checking otherwise defaults to the small model. This overlay preserves whatever selection already exists and does not silently enable a provider. Enterprise provider/network restrictions still apply.
5. **Linear status comments:** leave them off unless an already approved public HTTP(S) session origin is reachable by teammates. SSH-only, loopback, private LAN, and desktop links are skipped as `origin-not-public`; public DNS alone does not prove teammates can pass mTLS/access controls. Do not expose the server just to obtain comments. These native comments are session links, not custom implementation summaries.

Linear supports manual issue/session/worktree selection, not a built-in label-triggered dispatcher. A linked issue does not start autonomous work just because its label changes.

## Goals: opt in per task

The disabled goal setting stops the native continuation runtime; a disabled default budget would instead mean **no default token cap**, so the overlay deliberately keeps the budget switch on. It does not create or resume any goal. Existing scheduled prompts are a separate feature and are not disabled by these settings.

1. For an approved task, explicitly enable goals in Settings and keep a positive budget and a small auto-turn limit. Enabling the global setting can allow previously active goals to continue; inspect/pause old goals first.
2. Use the composer goal/target button for that task, provide a concrete objective, and inspect the task's budget before sending. “Run as goal” in a plan/fork/schedule flow is another explicit invocation, not a global label automation.
3. Watch the native goal status and pause it when needed. Turn goals off again when finished.

The budget is measured in tokens, **not dollars**, and is not a billing guarantee. Usage is checked after model turns; a turn can overshoot and checker/assist usage is separate. Permissions remain `ask`. Auto-turn limits must be 1–200; stored default budget values must be positive integers. Raise the shipped 20,000-token/one-continuation defaults only with explicit task approval.

## Repository examples (not deployed or scheduled)

`docs/examples/openchamber/project.json` is an inert example for `<repo>/.openchamber/project.json`. Its setup command only prints a reminder; its action shows Git status. Merge the desired fields into an existing project file instead of replacing it. Shared config uses `setupWorktree` / `setupWorktreeWait`; the personal runtime file uses different on-disk names (`setup-worktree` / `setup-worktree-wait`). Configure real setup/actions through the project UI after review. Do not manage `~/.config/openchamber/projects` from dotfiles.

`docs/examples/openchamber/review-changes.md` is a **disabled** loop example. Native portable loops live at `~/.agents/loops/*.md` (user-wide) or `.agents/loops/*.md` (project/ancestors within the worktree). Prefer project scope; manually choose an approved model and timezone before enabling. Discovery is not permission to execute. The example is not copied to either discovery location by chezmoi.

Loop frontmatter supports `name`, cron `schedule`, `enabled`, `model`, optional `agent`, and `timezone`; the body is the prompt. `thinking_level`, `goalEnabled`, and `goalTokenBudget` are **UI/JSON-only** in 2.1.1, not portable loop fields. Enable run-as-goal and its task budget in the scheduling UI only after explicit approval. Even a non-goal schedule spends tokens when enabled; disabled examples incur none. No container or service is needed for these examples, and no schedule is activated by this PR.
