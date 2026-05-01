# mcp-oauth-proxy

Bridges OAuth callback port mismatches between MCP tools and the IDE/editor
you're actually using.

## The problem

Some MCP tools (Slack, Datadog, etc.) are registered with Slack/the provider
as OAuth apps tied to a specific redirect URI — often the one a particular IDE
uses (e.g. VS Code on port `3118`). If your editor uses a different port
(e.g. OpenCode on port `19876`), the OAuth flow fails:

```
redirect_uri did not match any configured URIs.
Passed URI: http://127.0.0.1:19876/mcp/oauth/callback
```

`mcp_oauth_proxy.py` listens on the registered port, intercepts Slack's
callback, and forwards it — with all `code` and `state` parameters intact —
to your editor's actual port.

## Usage

```sh
python3 mcp_oauth_proxy.py <name>
```

`<name>` is a key in `proxies.json`. Run without arguments to list available
proxies.

**Two-terminal workflow:**

```sh
# Terminal 1 — start your editor's auth flow (spins up listener on target port)
opencode mcp auth slack

# Terminal 2 — start the proxy (polls until target listener is up)
python3 mcp_oauth_proxy.py slack
```

Then approve the OAuth request in the browser. The proxy forwards the callback,
prints what it received, and shuts itself down. Token is cached by your editor.

## Adding a proxy

Edit `proxies.json`. Each entry needs:

| Field | Description |
|---|---|
| `name` | Identifier, used as the CLI argument |
| `description` | Human-readable label (shown in help) |
| `listen_port` | Port the OAuth app's redirect URI points at (the IDE's port) |
| `target_port` | Port your editor's OAuth listener uses |
| `target_path` | Path your editor's OAuth listener expects (e.g. `/mcp/oauth/callback`) |
| `tool_auth_command` | Command to show in the "run this first" hint (optional) |
| `opencode_config` | Snippet to paste into your `opencode.json` (optional, for reference) |

Example — adding a Datadog MCP:

```json
{
  "name": "datadog",
  "description": "Datadog MCP — OAuth app registered for VS Code",
  "listen_port": 3119,
  "target_port": 19876,
  "target_path": "/mcp/oauth/callback",
  "tool_auth_command": "opencode mcp auth datadog",
  "opencode_config": {
    "mcp": {
      "datadog": {
        "type": "remote",
        "url": "https://mcp.datadoghq.com/api/unstable/mcp-server/mcp",
        "oauth": {
          "clientId": "<datadog-client-id>"
        }
      }
    }
  }
}
```

To find the right `listen_port` for a new MCP, check the `dev udf setup`
source (`dev/src/python/dev/platform/udf.py`) — the `callbackPort` field in
each MCP's `oauth` config is the port to use as `listen_port`.

## How it works

```
Browser
  │
  │  GET http://127.0.0.1:<listen_port>/<any-path>?code=XXX&state=YYY
  ▼
mcp_oauth_proxy.py
  │  logs incoming path  ← useful for debugging
  │  rewrites path to <target_path>
  │  preserves query string intact
  │
  │  GET http://127.0.0.1:<target_port><target_path>?code=XXX&state=YYY
  ▼
Your editor (OpenCode, etc.)
  │  validates state, exchanges code for token, caches it
  ▼
Response proxied back to browser
```

Path rewriting is necessary because the IDE's registered callback path may
differ from your editor's. The proxy accepts *any* incoming path and rewrites
it, so the mismatch is transparent to both sides. The incoming path is always
logged so you can see exactly what the provider sent.

## Troubleshooting

**`Error: port <N> is already in use`**  
Another process (e.g. VS Code) has already bound the listen port. Kill it:
```sh
lsof -ti :<port> | xargs kill
```

**`Timed out waiting for OAuth listener`**  
Run the auth command in the other terminal before starting the proxy, or
within the 60-second window.

**`state` mismatch / auth fails after forwarding**  
The proxy must not alter the query string. Check the logged query string
matches what your editor expects. If the provider is stripping or rewriting
params, check whether it requires HTTPS (it shouldn't for loopback).

## Requirements

Python 3.10+ (stdlib only, no dependencies).
