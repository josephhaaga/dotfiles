#!/usr/bin/env python3
"""Source-only Spaces Lab editor and the deployed yabai shortcut runtime."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shlex
import subprocess
import sys
import tempfile
from http.server import BaseHTTPRequestHandler, HTTPServer
import webbrowser

BEGIN = "# BEGIN SPACES LAB"
END = "# END SPACES LAB"
MODIFIERS = ("cmd", "ctrl", "alt", "shift")
IDENTIFIER = re.compile(r"^[a-z][a-z0-9-]{0,39}$")


def run(*args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=12)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ValueError(f"Could not run {args[0]}: {exc}") from exc
    if result.returncode:
        raise ValueError(result.stderr.strip() or f"{args[0]} failed ({result.returncode}).")
    return result.stdout


def query(kind):
    return json.loads(run("yabai", "-m", "query", f"--{kind}"))


def shortcut(value):
    if not isinstance(value, str):
        raise ValueError("Shortcut must be text.")
    if not value.strip():
        return ""
    match = re.fullmatch(r"\s*([a-z +]+)\s*-\s*([a-z0-9]|return|space|tab|escape|left|right|up|down)\s*", value)
    if not match:
        raise ValueError(f"Invalid shortcut: {value!r}. Use ctrl + alt - t, for example.")
    mods = [part.strip() for part in match[1].split("+")]
    if len(mods) != len(set(mods)) or any(mod not in MODIFIERS for mod in mods):
        raise ValueError(f"Invalid modifiers in {value!r}. Use cmd, ctrl, alt, or shift.")
    return " + ".join(mod for mod in MODIFIERS if mod in mods) + " - " + match[2]


def text(value, field, limit=100, allow_empty=False):
    if not isinstance(value, str) or len(value) > limit or any(ord(c) < 32 for c in value):
        raise ValueError(f"{field} must be plain text, at most {limit} characters.")
    value = value.strip()
    if not value and not allow_empty:
        raise ValueError(f"{field} is required.")
    return value


def validate(raw):
    if not isinstance(raw, dict) or raw.get("version") != 1:
        raise ValueError("Unsupported plan version.")
    spaces, apps = raw.get("spaces"), raw.get("apps")
    if not isinstance(spaces, list) or not isinstance(apps, list) or len(spaces) > 30 or len(apps) > 100:
        raise ValueError("A plan supports up to 30 spaces and 100 app shortcuts.")
    result = {"version": 1, "spaces": [], "apps": []}
    ids, keys, indices = set(), set(), set()
    for kind, entries in (("spaces", spaces), ("apps", apps)):
        for entry in entries:
            if not isinstance(entry, dict):
                raise ValueError("Each destination must be an object.")
            ident = entry.get("id")
            if not isinstance(ident, str) or not IDENTIFIER.fullmatch(ident) or ident in ids:
                raise ValueError("Destination IDs must be unique lowercase identifiers.")
            ids.add(ident)
            key = shortcut(entry.get("key", ""))
            if key and key in keys:
                raise ValueError(f"Two proposed destinations use {key}. Choose a different shortcut.")
            if key:
                keys.add(key)
            clean = {"id": ident, "key": key}
            if kind == "spaces":
                index = entry.get("index")
                if type(index) is not int or not 1 <= index <= 99 or index in indices:
                    raise ValueError("Space indices must be unique integers from 1 to 99.")
                indices.add(index)
                clean.update(index=index, name=text(entry.get("name"), "Space purpose", 60))
            else:
                space = entry.get("space")
                if space not in {s["id"] for s in result["spaces"]}:
                    raise ValueError("Every app shortcut must belong to a proposed space.")
                route = entry.get("route", False)
                if type(route) is not bool:
                    raise ValueError("App routing must be true or false.")
                clean.update(app=text(entry.get("app"), "App name"), space=space,
                             title=text(entry.get("title", ""), "Window title filter", 160, True), route=route)
            result[kind].append(clean)
    return result


def outside_block(skhd):
    if skhd.count(BEGIN) != 1 or skhd.count(END) != 1 or skhd.index(BEGIN) > skhd.index(END):
        raise ValueError("The skhd source must contain exactly one ordered SPACES LAB marker pair.")
    start, end = skhd.index(BEGIN), skhd.index(END) + len(END)
    return skhd[:start], skhd[end:]


def conflicts(plan, skhd):
    before, after = outside_block(skhd)
    existing = set()
    for line in (before + after).splitlines():
        if not line.strip() or line.lstrip().startswith("#") or ":" not in line:
            continue
        try:
            existing.add(shortcut(line.split(":", 1)[0]))
        except ValueError:
            continue
    return [f"{item['key']} is already used in your existing skhd config."
            for item in plan["spaces"] + plan["apps"] if item["key"] and item["key"] in existing]


def generate(plan, skhd):
    before, after = outside_block(skhd)
    errors = conflicts(plan, skhd)
    if errors:
        raise ValueError(" ".join(errors))
    lines = [BEGIN, "# Generated by scripts/yabai-spaces.sh. Existing bindings above stay intact."]
    for kind in ("spaces", "apps"):
        for item in plan[kind]:
            if item["key"]:
                lines.append(f"{item['key']} : \"$HOME/.local/bin/space-shortcuts\" focus {shlex.quote(item['id'])}")
    lines.append(END)
    return before + "\n".join(lines) + after


def target_space(plan, ident):
    space = next((s for s in plan["spaces"] if s["id"] == ident), None)
    if space is None:
        raise ValueError("This space no longer exists in the plan.")
    # A restored label survives renumbering. An unapplied draft tests its numeric index.
    live = query("spaces")
    actual = next((s for s in live if s.get("label") == f"spaceslab-{ident}"), None)
    actual = actual or next((s for s in live if s["index"] == space["index"]), None)
    if actual is None or actual.get("is-native-fullscreen"):
        raise ValueError(f"Space {space['index']} is missing or fullscreen. Choose an existing desktop.")
    return actual["index"]


def focus(plan, ident, draft=False):
    space = next((s for s in plan["spaces"] if s["id"] == ident), None)
    if space:
        if draft:
            # Draft changes must not resolve a previous label on a different index.
            live = query("spaces")
            if not any(s["index"] == space["index"] and not s.get("is-native-fullscreen") for s in live):
                raise ValueError(f"Desktop {space['index']} does not exist. Create it in Mission Control first.")
            index = space["index"]
        else:
            index = target_space(plan, ident)
        run("yabai", "-m", "space", "--focus", str(index))
        return f"Focused {space['name']} (space {index})."
    app = next((a for a in plan["apps"] if a["id"] == ident), None)
    if app is None:
        raise ValueError("Unknown shortcut destination.")
    windows = [w for w in query("windows") if w.get("app") == app["app"]
               and app["title"].casefold() in w.get("title", "").casefold()]
    windows.sort(key=lambda w: (not w.get("has-focus", False), w["id"]))
    if windows:
        run("yabai", "-m", "window", "--focus", str(windows[0]["id"]))
        return f"Focused {app['app']} on space {windows[0]['space']}."
    if app["title"]:
        raise ValueError(f"No {app['app']} window matches the title filter. Open that window or clear the filter.")
    run("open", "-a", app["app"])
    return f"Opened {app['app']}."


def restore(plan):
    live = query("spaces")
    # Remove only this tool's rules so repeated restores are idempotent.
    for rule in json.loads(run("yabai", "-m", "rule", "--list")):
        label = rule.get("label", "")
        if label.startswith("spaceslab-"):
            run("yabai", "-m", "rule", "--remove", label)
    planned_labels = {f"spaceslab-{s['id']}" for s in plan["spaces"]}
    for space in live:
        label = space.get("label", "")
        if label.startswith("spaceslab-") and label not in planned_labels:
            run("yabai", "-m", "space", str(space["index"]), "--label")
    valid = set()
    errors = []
    for space in plan["spaces"]:
        index = space["index"]
        if not any(s["index"] == index and not s.get("is-native-fullscreen") for s in live):
            errors.append(f"Skipped {space['name']}: desktop {index} is missing or fullscreen.")
            continue
        run("yabai", "-m", "space", str(index), "--label", f"spaceslab-{space['id']}")
        valid.add(space["id"])
    for app in plan["apps"]:
        if app["route"] and app["space"] in valid:
            args = ["yabai", "-m", "rule", "--add", f"label=spaceslab-{app['id']}",
                    f"app=^{regex_literal(app['app'])}$", f"space=spaceslab-{app['space']}"]
            if app["title"]:
                args.append(f"title={regex_literal(app['title'])}")
            run(*args)
    if errors:
        raise ValueError(" ".join(errors))


def regex_literal(value):
    # yabai uses POSIX ERE, not Python's regex dialect.
    return re.sub(r"([.\[\]\\*+?{}()|^$])", r"\\\1", value)


def atomic_write(path, value):
    fd, name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as file:
            file.write(value)
        os.chmod(name, path.stat().st_mode & 0o777)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


class Source:
    def __init__(self, root):
        self.root = Path(root).resolve()
        if (self.root / ".chezmoiroot").read_text().strip() != "home":
            raise ValueError("Select the dotfiles repository with its active home/ source.")
        self.config = self.root / "home/dot_config/yabai/space-shortcuts.json"
        self.skhd = self.root / "home/executable_dot_skhdrc"
        self.html = self.root / "home/dot_local/share/yabai-spaces/index.html"

    def revision(self):
        return hashlib.sha256(self.config.read_bytes() + self.skhd.read_bytes()).hexdigest()

    def preview(self, raw):
        plan = validate(raw)
        generated = generate(plan, self.skhd.read_text())
        return {"plan": plan, "skhd": generated.split(BEGIN, 1)[1].split(END, 1)[0].strip(),
                "json": json.dumps(plan, indent=2) + "\n"}

    def save(self, raw, revision):
        if revision != self.revision():
            raise ValueError("Source changed since you loaded it. Reload the page before saving.")
        preview = self.preview(raw)
        old_config = self.config.read_text()
        generated = generate(preview["plan"], self.skhd.read_text())
        atomic_write(self.config, preview["json"])
        try:
            atomic_write(self.skhd, generated)
        except OSError:
            atomic_write(self.config, old_config)
            raise
        return {"revision": self.revision(), "message": "Saved to source. Live hotkeys have not changed."}


def inventory():
    try:
        spaces, windows = query("spaces"), query("windows")
        # Never return or persist live window titles.
        return {"spaces": [{"index": s["index"], "display": s.get("display"),
                            "focused": s.get("has-focus", False), "fullscreen": s.get("is-native-fullscreen", False),
                            "apps": sorted({w["app"] for w in windows if w.get("space") == s["index"]})}
                           for s in spaces], "error": None}
    except (ValueError, KeyError, json.JSONDecodeError) as exc:
        return {"spaces": [], "error": str(exc)}


def serve(source, port, launch):
    token = secrets.token_urlsafe(32)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def respond(self, status, payload, content_type="application/json"):
            body = payload.encode() if isinstance(payload, str) else json.dumps(payload).encode()
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Content-Security-Policy", "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; img-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
            self.end_headers()
            self.wfile.write(body)

        def allowed(self, api=False):
            host = f"127.0.0.1:{self.server.server_port}"
            if self.headers.get("Host") != host:
                self.respond(403, {"error": "Use the printed 127.0.0.1 URL."})
                return False
            origin = self.headers.get("Origin")
            if origin and origin != f"http://{host}":
                self.respond(403, {"error": "Cross-origin requests are not allowed."})
                return False
            if api and not secrets.compare_digest(self.headers.get("X-Spaces-Token", ""), token):
                self.respond(403, {"error": "Reload the local tool to authenticate."})
                return False
            return True

        def do_GET(self):
            if not self.allowed(api=self.path.startswith("/api/")):
                return
            try:
                if self.path == "/":
                    self.respond(200, source.html.read_text().replace("__SPACES_TOKEN__", token), "text/html; charset=utf-8")
                elif self.path == "/api/state":
                    self.respond(200, {"plan": validate(json.loads(source.config.read_text())),
                                       "revision": source.revision(), "inventory": inventory()})
                elif self.path == "/api/inventory":
                    self.respond(200, inventory())
                else:
                    self.respond(404, {"error": "Not found."})
            except (ValueError, OSError) as exc:
                self.respond(400, {"error": str(exc)})

        def do_POST(self):
            if not self.allowed(api=True):
                return
            try:
                size = int(self.headers.get("Content-Length", "0"))
                if size <= 0 or size > 65536:
                    raise ValueError("Request must be between 1 and 65536 bytes.")
                data = json.loads(self.rfile.read(size))
                if not isinstance(data, dict):
                    raise ValueError("Request must be an object.")
                if self.path == "/api/preview":
                    result = source.preview(data.get("plan"))
                elif self.path == "/api/save":
                    result = source.save(data.get("plan"), data.get("revision"))
                elif self.path == "/api/test":
                    result = {"message": focus(validate(data.get("plan")), data.get("id"), draft=True)}
                else:
                    self.respond(404, {"error": "Not found."})
                    return
                self.respond(200, result)
            except (ValueError, OSError, KeyError) as exc:
                self.respond(400, {"error": str(exc)})

    # Serialize writes and tests; the tiny local UI needs no worker concurrency.
    with HTTPServer(("127.0.0.1", port), Handler) as server:
        url = f"http://127.0.0.1:{server.server_port}"
        print(f"Spaces Lab: {url}\nSource: {source.root}\nCtrl-C stops the server.", flush=True)
        if launch:
            webbrowser.open(url)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    editor = sub.add_parser("serve", help="Launch the source-only browser editor")
    editor.add_argument("--source", required=True)
    editor.add_argument("--port", type=int, default=0)
    editor.add_argument("--no-open", action="store_true")
    destination = sub.add_parser("focus", help="Focus a configured purpose or app")
    destination.add_argument("id")
    sub.add_parser("restore", help="Restore labels and future-window routing at yabai startup")
    args = parser.parse_args()
    try:
        if args.command == "serve":
            serve(Source(args.source), args.port, not args.no_open)
        else:
            config = Path.home() / ".config/yabai/space-shortcuts.json"
            plan = validate(json.loads(config.read_text()))
            if args.command == "focus":
                print(focus(plan, args.id))
            else:
                restore(plan)
    except (ValueError, OSError) as exc:
        print(f"Spaces Lab: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
