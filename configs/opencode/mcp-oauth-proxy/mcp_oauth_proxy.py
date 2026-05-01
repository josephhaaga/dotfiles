#!/usr/bin/env python3
"""
mcp_oauth_proxy.py

Bridges OAuth callback port mismatches between MCP tools that are registered
for one IDE (e.g. VS Code) and the tool you're actually using (e.g. OpenCode).

When a tool's OAuth app is registered with a redirect URI pointing at a
specific port (e.g. 3118), but your local client listens on a different port
(e.g. 19876), authentication fails. This proxy listens on the registered port
and forwards callbacks — with all query parameters intact — to your client's
actual port.

Usage:
  python3 mcp_oauth_proxy.py <name>

  <name> must match a "name" field in proxies.json (in the same directory).

  Terminal 1:  opencode mcp auth <name>    (or equivalent for your tool)
  Terminal 2:  python3 mcp_oauth_proxy.py <name>
  Then complete the browser OAuth flow.

See README.md for full context.
"""

import http.server
import json
import os
import socket
import socketserver
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(SCRIPT_DIR, "proxies.json")

# How long to wait (seconds) for the target listener to come up before giving up.
TARGET_WAIT_TIMEOUT = 60
TARGET_POLL_INTERVAL = 0.25


# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------

def load_proxy_config(name: str) -> dict:
    """Load and validate a named proxy entry from proxies.json."""
    if not os.path.exists(CONFIG_FILE):
        print(f"Error: config file not found: {CONFIG_FILE}")
        sys.exit(1)

    with open(CONFIG_FILE) as f:
        try:
            config = json.load(f)
        except json.JSONDecodeError as e:
            print(f"Error: invalid JSON in {CONFIG_FILE}: {e}")
            sys.exit(1)

    proxies = config.get("proxies", [])
    matches = [p for p in proxies if p.get("name") == name]

    if not matches:
        available = [p.get("name", "?") for p in proxies]
        print(f"Error: no proxy named '{name}' in {CONFIG_FILE}")
        print(f"Available: {', '.join(available) if available else '(none)'}")
        sys.exit(1)

    proxy = matches[0]

    required = ("name", "listen_port", "target_port", "target_path")
    missing = [k for k in required if k not in proxy]
    if missing:
        print(f"Error: proxy '{name}' is missing required fields: {', '.join(missing)}")
        sys.exit(1)

    return proxy


# ---------------------------------------------------------------------------
# Network helpers
# ---------------------------------------------------------------------------

def port_is_listening(host: str, port: int) -> bool:
    """Return True if something is accepting TCP connections on host:port."""
    try:
        with socket.create_connection((host, port), timeout=0.5):
            return True
    except OSError:
        return False


def check_listen_port_free(port: int) -> None:
    """Exit with a clear message if the listen port is already in use."""
    if port_is_listening("127.0.0.1", port):
        print(
            f"Error: port {port} is already in use.\n"
            f"Another process (e.g. VS Code) may have already bound this port.\n"
            f"Find and stop it, then try again:\n"
            f"\n  lsof -ti :{port}   # find the PID"
            f"\n  kill <PID>          # stop it"
        )
        sys.exit(1)


def wait_for_target(port: int, auth_command: str | None, timeout: int = TARGET_WAIT_TIMEOUT) -> bool:
    """Poll until the target OAuth listener is up. Returns False on timeout."""
    hint = auth_command or f"start your MCP client's auth flow (target port: {port})"
    deadline = time.monotonic() + timeout
    print(f"Waiting for OAuth listener on port {port}...")
    print(f"  → Run '{hint}' now if you haven't already.")
    while time.monotonic() < deadline:
        if port_is_listening("127.0.0.1", port):
            print(f"  ✓ Listener is up on port {port}.")
            return True
        time.sleep(TARGET_POLL_INTERVAL)
    return False


# ---------------------------------------------------------------------------
# HTTP proxy
# ---------------------------------------------------------------------------

class _StopServer(Exception):
    pass


def make_handler(target_port: int, target_path: str):
    """Return a handler class closed over the target address."""

    class CallbackHandler(http.server.BaseHTTPRequestHandler):
        """
        Accepts any GET on any path, rewrites to the target callback URL,
        preserves the full query string, and returns the target's response.
        """

        def log_message(self, fmt, *args):
            # Suppress default per-request stderr noise; we do our own logging.
            pass

        def do_GET(self):
            parsed = urllib.parse.urlparse(self.path)
            query = parsed.query

            print(f"\nCallback received:")
            print(f"  Incoming path : {parsed.path}")
            print(f"  Query string  : {query}")

            target_url = f"http://127.0.0.1:{target_port}{target_path}"
            if query:
                target_url = f"{target_url}?{query}"

            print(f"  Forwarding to : {target_url}")

            try:
                with urllib.request.urlopen(target_url, timeout=10) as resp:
                    body = resp.read()
                    status = resp.status
                    content_type = resp.headers.get("Content-Type", "text/plain")
            except urllib.error.HTTPError as e:
                body = e.read()
                status = e.code
                content_type = e.headers.get("Content-Type", "text/plain")
            except Exception as e:
                print(f"  Error forwarding to target: {e}")
                self.send_error(502, f"Proxy error: {e}")
                return

            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

            print(f"  Target responded with HTTP {status}")
            print(f"\nAuth flow complete. Shutting down proxy.")

            raise _StopServer()

    return CallbackHandler


class OneRequestServer(socketserver.TCPServer):
    allow_reuse_address = True

    def handle_error(self, request, client_address):
        # Propagate _StopServer so serve_forever can catch it.
        _, v, _ = sys.exc_info()
        if isinstance(v, _StopServer):
            raise v
        super().handle_error(request, client_address)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) != 2 or sys.argv[1] in ("-h", "--help"):
        print(__doc__)
        print(f"\nAvailable proxies (from {CONFIG_FILE}):")
        try:
            with open(CONFIG_FILE) as f:
                config = json.load(f)
            for p in config.get("proxies", []):
                name = p.get("name", "?")
                desc = p.get("description", "")
                print(f"  {name}" + (f"  —  {desc}" if desc else ""))
        except Exception:
            print("  (could not read proxies.json)")
        sys.exit(0 if len(sys.argv) == 1 else 1)

    proxy = load_proxy_config(sys.argv[1])

    listen_port = proxy["listen_port"]
    target_port = proxy["target_port"]
    target_path = proxy["target_path"]
    auth_command = proxy.get("tool_auth_command")
    name = proxy["name"]

    check_listen_port_free(listen_port)

    if not wait_for_target(target_port, auth_command):
        print(
            f"\nTimed out after {TARGET_WAIT_TIMEOUT}s waiting for the OAuth listener on port {target_port}.\n"
            f"Make sure you start the auth flow before or shortly after starting this proxy."
        )
        sys.exit(1)

    print(f"\nProxy '{name}' started:")
    print(f"  Listening : http://127.0.0.1:{listen_port}")
    print(f"  Target    : http://127.0.0.1:{target_port}{target_path}")
    print(f"\n  Complete the OAuth flow in your browser now.\n")

    handler = make_handler(target_port, target_path)
    with OneRequestServer(("127.0.0.1", listen_port), handler) as server:
        try:
            server.serve_forever(poll_interval=0.1)
        except _StopServer:
            pass


if __name__ == "__main__":
    main()
