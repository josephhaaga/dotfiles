# Hub

A local dev dashboard — a PWA that lists all running services (OpenPortal instances, Docker containers, and fixed evergreen tools) with live online/offline status. Designed for phone access over Tailscale.

## Usage

**Run the full stack from a project directory:**

```sh
bun run ~/.config/opencode/hub/server.ts
```

This will:
1. Clean up stale openportal entries for the current directory
2. Start openportal (OpenCode + web UI), with auto-assigned ports
3. Start the Hub HTTP server on port 8080 (skipped if already running)
4. Print Tailscale URLs and wait — Ctrl-C tears everything down

**Access from your phone:** `http://<tailscale-ip>:8080`

## Auto-start with OpenCode

The plugin at `../plugins/hub.ts` is loaded globally by OpenCode. It starts the Hub server automatically whenever OpenCode opens, so you don't need to run `server.ts` manually just to get the dashboard.

openportal is *not* started by the plugin — only by running `server.ts` directly.

## PWA install

Open `http://<tailscale-ip>:8080` in Safari on iOS, tap Share → Add to Home Screen. The app title is "Hub".

## Services shown

| Section | Source |
|---|---|
| **Evergreen** | Hardcoded in `server.ts` (Plannotator, Hub itself) |
| **📁 project-name** | Live openportal instances from `~/.portal.json` |
| **🐳 project-name** | Docker containers with published ports (`docker ps`) |

Services are probed concurrently on each `/api/services` request — green dot = responding, grey = offline.

## Configuration

| Env var | Default | Description |
|---|---|---|
| `DEV_HOME_PORT` | `8080` | Port Hub listens on |
| `PLANNOTATOR_PORT` | `19432` | Plannotator fixed port |
