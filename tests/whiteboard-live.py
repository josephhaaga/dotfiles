#!/usr/bin/env python3
"""Opt-in integration test: real hosts + deterministic local model, no accounts."""
import argparse
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


def request(url, method="GET", body=None, headers=None):
    data = None if body is None else json.dumps(body).encode()
    req = Request(url, data=data, method=method, headers={"Content-Type": "application/json", **(headers or {})})
    with urlopen(req, timeout=30) as response:
        raw = response.read()
        return json.loads(raw) if raw else None


def port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def wait_ready(url, process):
    for _ in range(150):
        if process.poll() is not None:
            raise RuntimeError(f"Host exited with {process.returncode}; inspect the printed fixture directory")
        try:
            return request(url)
        except (URLError, TimeoutError):
            time.sleep(0.2)
    raise RuntimeError(f"Host did not become ready: {url}")


def stop(process):
    if process and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


class Model(BaseHTTPRequestHandler):
    """Exercise host tool dispatch; this is not an evaluation of model judgment."""
    errors = []
    requests = 0
    native_contexts = []
    native_policy_seen = False
    native_board_contexts = []

    def log_message(self, *_args):
        pass

    def do_POST(self):
        type(self).requests += 1
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        try:
            users = [m for m in body["messages"] if m["role"] == "user"]
            text = users[-1]["content"] if users else ""
            if isinstance(text, list):
                text = "\n".join(p.get("text", "") for p in text)
            if "<whiteboard-context>" in text:
                self.native_board_contexts.append(text)
                type(self).native_policy_seen |= any(
                    m["role"] == "system" and "# Whiteboard mode" in json.dumps(m.get("content", ""))
                    for m in body["messages"]
                )
            marker = "FIXTURE_TOOL_JSON:"
            tools = {t["function"]["name"] for t in body.get("tools", [])}
            # Auxiliary title requests have no tool catalog.
            if marker not in text or not tools:
                delta, finish = {"content": "Fixture"}, "stop"
            elif body["messages"][-1]["role"] == "tool":
                try:
                    content = body["messages"][-1]["content"]
                    if isinstance(content, list):
                        content = "\n".join(p.get("text", "") for p in content)
                    context = json.loads(content)
                    if isinstance(context, dict) and context.get("nativeChat"):
                        self.native_contexts.append(context)
                except (ValueError, TypeError):
                    pass
                delta, finish = {"content": "Fixture tool completed."}, "stop"
            else:
                operation = json.loads(text.split(marker, 1)[1].splitlines()[0])
                tool_name, tool_input = operation["tool"], operation["input"]
                if tool_name.startswith("whiteboard_session_") and tool_name not in tools:
                    # Exercise the production MCP Code Mode path too. Names
                    # come from this installed server's verified tool catalog.
                    method = tool_name.removeprefix("whiteboard_")
                    tool_name = "execute"
                    tool_input = {"code": f"return await tools.whiteboard.{method}({json.dumps(tool_input)});"}
                assert tool_name in tools, (tool_name, sorted(tools))
                delta, finish = {"tool_calls": [{"index": 0, "id": "call_fixture", "type": "function", "function": {
                    "name": tool_name, "arguments": json.dumps(tool_input),
                }}]}, "tool_calls"
            chunk = {"id": "fixture", "object": "chat.completion.chunk", "created": 0, "model": "fixture", "choices": [
                {"index": 0, "delta": {"role": "assistant", **delta}, "finish_reason": None},
            ]}
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.end_headers()
            self.wfile.write(("data: " + json.dumps(chunk) + "\n\n").encode())
            chunk["choices"] = [{"index": 0, "delta": {}, "finish_reason": finish}]
            self.wfile.write(("data: " + json.dumps(chunk) + "\n\ndata: [DONE]\n\n").encode())
        except Exception as error:
            self.errors.append(str(error))
            self.send_error(500)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-isolated-servers", action="store_true")
    parser.add_argument("--whiteboard", default=str(Path.home() / ".local/bin/whiteboard"))
    args = parser.parse_args()
    if not args.allow_isolated_servers:
        parser.error("Explicit opt-in required: --allow-isolated-servers")
    source = Path(__file__).resolve().parents[1]
    base = Path(os.environ.get("TMPDIR", tempfile.gettempdir()))
    if (base / "opencode").is_dir():
        base /= "opencode"
    root = Path(tempfile.mkdtemp(prefix="whiteboard-live-", dir=base)).resolve()
    print(f"Synthetic fixture and logs: {root}", flush=True)
    home, repo, config = root / "home", root / "repo", root / "config/opencode"
    repo.mkdir()
    config.mkdir(parents=True)
    home.mkdir()
    env = {key: os.environ[key] for key in ("PATH", "TMPDIR", "LANG") if key in os.environ}
    env.update({
        "HOME": str(home), "XDG_CONFIG_HOME": str(root / "config"),
        "XDG_DATA_HOME": str(root / "data"), "XDG_STATE_HOME": str(root / "state"),
        "XDG_CACHE_HOME": str(root / "cache"), "OPENCODE_DB": str(root / "host.db"),
        "DEV_REVIEW_HOME": str(root / "dev"), "DEV_FAST_REVIEW_CLI_NO_DELEGATE": "1",
        "DO_NOT_TRACK": "1", "FIXTURE_API_KEY": "synthetic-not-a-credential",
    })
    opencode = shutil.which("opencode")
    assert opencode and Path(args.whiteboard).is_file(), "Install OpenCode and the Whiteboard CLI first"
    subprocess.run(["git", "init", "-q", str(repo)], check=True, env=env)
    subprocess.run(["git", "-C", str(repo), "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                    "commit", "--allow-empty", "-qm", "Synthetic fixture"], check=True, env=env)
    shutil.copytree(source / "home/dot_config/opencode/agents", config / "agents")
    model = ThreadingHTTPServer(("127.0.0.1", 0), Model)
    thread = threading.Thread(target=model.serve_forever, daemon=True)
    thread.start()
    wb_port, oc_port = port(), port()
    wb_base, oc_base = f"http://127.0.0.1:{wb_port}", f"http://127.0.0.1:{oc_port}"
    wb_command = [str(Path(args.whiteboard).resolve()), "--state-dir", str(root / "boards")]
    rendered = json.loads(subprocess.check_output(
        ["chezmoi", "execute-template", "--source", str(source), "--override-data", '{"profile":"desktop"}'],
        input=(source / "home/dot_config/opencode/opencode.json.tmpl").read_bytes(), env=env,
    ))
    config_data = {
        "$schema": "https://opencode.ai/config.json",
        "plugins": [str(source / "home/dot_config/opencode/local-plugins/whiteboard")],
        "commands": rendered["commands"],
        "providers": {"fixture": {
            "name": "Synthetic local fixture", "env": ["FIXTURE_API_KEY"],
            "package": "@opencode/ai/providers/openai-compatible",
            "settings": {"baseURL": f"http://127.0.0.1:{model.server_port}/v1", "encoding": "none"},
            "models": {"fixture": {"capabilities": {"tools": True, "input": ["text"], "output": ["text"]},
                                    "limit": {"context": 32000, "output": 1000}}},
        }},
        "mcp": {"servers": {"whiteboard": {"type": "local", "command": wb_command + ["mcp"]}}},
    }
    (config / "opencode.json").write_text(json.dumps(config_data))
    processes, logs = [], []

    def start(command, log_name, ready):
        log_path = root / log_name
        log_offset = log_path.stat().st_size if log_path.exists() else 0
        log = log_path.open("a")
        logs.append(log)
        process = subprocess.Popen(command, cwd=repo, env=env, stdout=log, stderr=subprocess.STDOUT)
        processes.append(process)
        if command[0] == opencode:
            # `serve` generates a private password. Use the supported client
            # auth environment, never an unauthenticated host HTTP request.
            for _ in range(150):
                text = log_path.read_text()[log_offset:]
                passwords = [line.removeprefix("server password ") for line in text.splitlines()
                             if line.startswith("server password ")]
                if passwords:
                    env["OPENCODE_PASSWORD"] = passwords[-1]
                    break
                if "server listening on " in text and env.get("OPENCODE_PASSWORD"):
                    break  # A restarted test host retains its supplied password.
                if process.poll() is not None:
                    raise RuntimeError("OpenCode exited; inspect its fixture log")
                time.sleep(0.2)
            else:
                raise RuntimeError("OpenCode did not publish its private test password")
            api("/api/info")
        else:
            wait_ready(ready, process)
        return process

    def wb(tool, payload):
        if tool == "session_get":
            payload = {**payload, "format": "json"}
        output = subprocess.check_output(wb_command + ["api", tool, json.dumps(payload)], env=env, cwd=repo, timeout=30)
        return json.loads(output)

    def native_request(path, method="GET", payload=None):
        # Authenticate only to this test's isolated Whiteboard server. This is
        # the same backend API used by the installed Chat with agent / Ask UI.
        discovery = json.loads((root / "boards/review-server/server.json").read_text())
        assert discovery["url"] == wb_base
        return request(wb_base + "/reviews-api" + path, method, payload,
                       {"x-review-token": discovery["token"]})

    def native_snapshot(board, thread_id):
        discovery = json.loads((root / "boards/review-server/server.json").read_text())
        req = Request(wb_base + f"/reviews-api/{board}/ask/watch", method="POST",
                      data=json.dumps({"threads": [thread_id]}).encode(),
                      headers={"Content-Type": "application/json", "x-review-token": discovery["token"]})
        with urlopen(req, timeout=10) as response:
            return json.loads(response.readline())["update"]["snapshot"]

    def native_wait(board, thread_id, turns):
        for _ in range(150):
            snapshot = native_snapshot(board, thread_id)
            if snapshot["status"] in ("failed", "waiting"):
                raise AssertionError(snapshot)
            answers = [e for e in snapshot["entries"] if e["kind"] == "agent"]
            if snapshot["status"] == "idle" and len(answers) >= turns:
                (root / "native-chat.json").write_text(json.dumps(snapshot, indent=2))
                return snapshot
            time.sleep(0.2)
        raise AssertionError(snapshot)

    def native_question(tool, payload):
        return {"text": "FIXTURE_TOOL_JSON:" + json.dumps({"tool": tool, "input": payload})}

    location = "?" + urlencode({"location[directory]": str(repo)})

    def api(path, method="GET", payload=None):
        command = [opencode, "--server", oc_base, "api", method.lower(), path + location]
        if payload is not None:
            command += ["--data", json.dumps(payload)]
        output = subprocess.check_output(command, env=env, cwd=repo, timeout=20 if path.endswith("/wait") else 60)
        return json.loads(output) if output.strip() else None

    def invoke(session, tool, payload, error=False, via_command=False):
        prompt = "FIXTURE_TOOL_JSON:" + json.dumps({"tool": tool, "input": payload})
        if via_command:
            api(f"/api/session/{session}/command", "POST", {"name": "whiteboard", "text": prompt})
        else:
            api(f"/api/session/{session}/prompt", "POST", {"text": prompt})
        try:
            api(f"/api/experimental/session/{session}/wait", "POST", {})
        except subprocess.TimeoutExpired:
            diagnostic = {"modelRequests": Model.requests, "modelErrors": Model.errors,
                          "context": api(f"/api/session/{session}/context"),
                          "permissions": api(f"/api/session/{session}/permission")}
            (root / "timeout.json").write_text(json.dumps(diagnostic, indent=2))
            raise RuntimeError(f"Tool dispatch timed out; see {root / 'timeout.json'}") from None
        messages = api(f"/api/session/{session}/context")
        # Persist the sanitized synthetic transcript for diagnosis and evidence.
        (root / f"{session}.json").write_text(json.dumps(messages, indent=2))
        if isinstance(messages, dict):
            messages = messages["data"]
        dispatched = "execute" if tool.startswith("whiteboard_session_") else tool
        calls = [part for message in messages if message.get("type") == "assistant"
                 for part in message.get("content", []) if part.get("type") == "tool" and part.get("name") == dispatched]
        assert calls, (tool, messages, Model.errors)
        state = calls[-1]["state"]
        # Code Mode completes its outer call while reporting a failed nested
        # tool in metadata; native tool failures use status:error directly.
        failed = state["status"] == "error" or state.get("metadata", {}).get("error") is True
        assert failed == error and state["status"] in ("completed", "error"), state
        return state

    def wait_mode():
        for _ in range(30):
            agents = api("/api/agent")
            plugins = api("/api/plugin")
            servers = api("/api/mcp")
            registered = [p for p in plugins.get("data", []) if p.get("id") == "dotfiles.whiteboard"]
            connected = any(s["name"] == "whiteboard" and s["status"]["status"] == "connected" for s in servers.get("data", []))
            if "Whiteboard mode" in json.dumps(agents) and registered and registered[0]["state"]["status"] == "active" and connected:
                break
            time.sleep(0.2)
        (root / "agents.json").write_text(json.dumps(agents, indent=2))
        (root / "plugins.json").write_text(json.dumps(plugins, indent=2))
        assert "Whiteboard mode" in json.dumps(agents), agents
        assert "dotfiles.whiteboard" in json.dumps(plugins), plugins
        assert connected, servers

    try:
        whiteboard = start(wb_command + ["server", "start", "--port", str(wb_port)], "whiteboard.log", wb_base + "/health")
        host = start([opencode, "serve", "--hostname", "127.0.0.1", "--port", str(oc_port)], "opencode.log", oc_base + "/api/info")
        wait_mode()
        capabilities = wb("session_capabilities", {})
        assert capabilities is not None
        boards = []
        for suffix in ("alpha", "beta"):
            created = wb("session_create", {"title": f"Synthetic {suffix}", "target": {"kind": "project", "repositoryPath": str(repo)}, "open": False})
            (root / f"create-{suffix}.json").write_text(json.dumps(created, indent=2))
            board = created.get("session", created.get("review", created))
            boards.append(board["sessionId"])
        sessions = []
        for _ in boards:
            session = api("/api/session", "POST", {"title": "Synthetic Whiteboard test"})
            session = session.get("data", session)
            sid = session["id"]
            sessions.append(sid)
            api(f"/api/session/{sid}/model", "POST", {"model": {"providerID": "fixture", "id": "fixture"}})
        status = wb("whiteboard_status", {})
        (root / "status.json").write_text(json.dumps(status, indent=2))
        instance = status.get("instance", status)
        key = instance.get("key", status.get("key"))
        assert key, status
        for sid, board in zip(sessions, boards):
            invoke(sid, "whiteboard_bind", {"boardID": board, "instanceKey": key}, via_command=True)
            invoke(sid, "whiteboard_context", {})
        print("PASS /whiteboard primary-agent routing, V2 plugin loading, and two session bindings", flush=True)
        activity = wb("session_activity_begin", {"sessionId": boards[0]})
        activity_id = activity["activityId"]
        for step in range(1, 4):
            invoke(sessions[0], "whiteboard_session_edit", {"sessionId": boards[0], "activityId": activity_id,
                "edit": {"type": "insert", "content": {"type": "markdown", "markdown": f"Synthetic update {step}."}}})
        invoke(sessions[0], "whiteboard_session_edit", {"sessionId": boards[1], "activityId": activity_id,
            "edit": {"type": "insert", "content": {"type": "markdown", "markdown": "WRONG BOARD"}}}, error=True)
        assert "WRONG BOARD" not in json.dumps(wb("session_get", {"sessionId": boards[1], "full": True}))
        # This simulates a user-authored board edit, NOT delivery of a native comment.
        wb("session_edit", {"sessionId": boards[0], "activityId": activity_id,
            "edit": {"type": "insert", "content": {"type": "markdown", "markdown": "Synthetic feedback: add evidence."}}})
        feedback = invoke(sessions[0], "whiteboard_session_get", {"sessionId": boards[0], "full": True})
        assert "Synthetic feedback: add evidence." in json.dumps(feedback), feedback
        invoke(sessions[0], "whiteboard_session_edit", {"sessionId": boards[0], "activityId": activity_id,
            "edit": {"type": "insert", "content": {"type": "markdown", "markdown": "Evidence added after explicit resume."}}})
        wb("session_activity_end", {"sessionId": boards[0], "activityId": activity_id})
        print("PASS three live MCP edits, cross-board rejection, explicit-resume feedback round trip", flush=True)
        before = wb("session_get", {"sessionId": boards[0], "full": True})
        for marker in ("Synthetic update 1.", "Synthetic update 2.", "Synthetic update 3.", "Evidence added after explicit resume."):
            assert marker in json.dumps(before), (marker, before)
        stop(host)
        stop(whiteboard)
        whiteboard = start(wb_command + ["server", "start", "--port", str(wb_port)], "whiteboard.log", wb_base + "/health")
        host = start([opencode, "serve", "--hostname", "127.0.0.1", "--port", str(oc_port)], "opencode.log", oc_base + "/api/info")
        wait_mode()
        for sid, board in zip(sessions, boards):
            state = invoke(sid, "whiteboard_context", {})
            assert board in json.dumps(state), state
        after = wb("session_get", {"sessionId": boards[0], "full": True})
        assert before == after, "Board changed across restart"
        print("PASS real OpenCode + Whiteboard host restart preserves bindings and board content", flush=True)

        # Unlike the preceding terminal/API prompts, every question below is
        # sent to Whiteboard's own Ask API. Whiteboard launches the real CLI
        # over ACP and supplies its scoped MCP server, just as Desktop does.
        native_board = boards[0]
        started = native_request(f"/{native_board}/ask", "POST", {
            "agent": "opencode", "permissions": "read-only", "picks": {"model": "fixture/fixture"},
            "selection": {"target": {"kind": "review"}, "title": "Synthetic native chat"},
            "question": native_question("whiteboard_context", {}),
        })
        thread_id = started["threadId"]
        native_wait(native_board, thread_id, 1)
        assert Model.native_policy_seen, "Native ACP Build did not receive the board-first system policy"
        assert any(native_board in text for text in Model.native_board_contexts), "App did not deliver the selected board context"
        assert Model.native_contexts and Model.native_contexts[-1]["nativeChat"]["threadID"] == thread_id, Model.native_contexts
        native_session = Model.native_contexts[-1]["sessionID"]
        assert native_session not in sessions, "Native Chat must not silently attach to a terminal session"
        native_request(f"/{native_board}/ask/{thread_id}/prompt", "POST", {
            "question": native_question("whiteboard_bind", {"boardID": native_board, "instanceKey": key}),
        })
        native_wait(native_board, thread_id, 2)
        native_activity = wb("session_activity_begin", {"sessionId": native_board})["activityId"]
        native_request(f"/{native_board}/ask/{thread_id}/prompt", "POST", {
            "question": native_question("whiteboard_session_edit", {"sessionId": native_board, "activityId": native_activity,
                "edit": {"type": "insert", "content": {"type": "markdown", "markdown": "Written from native Whiteboard Chat via ACP."}}}),
        })
        native_wait(native_board, thread_id, 3)
        assert "Written from native Whiteboard Chat via ACP." in json.dumps(wb("session_get", {"sessionId": native_board, "full": True}))
        native_request(f"/{native_board}/ask/{thread_id}/close", "POST", {})
        native_request(f"/{native_board}/ask/{thread_id}/open", "POST", {})
        native_wait(native_board, thread_id, 3)
        native_request(f"/{native_board}/ask/{thread_id}/prompt", "POST", {"question": native_question("whiteboard_context", {})})
        native_wait(native_board, thread_id, 4)
        assert Model.native_contexts[-1]["sessionID"] == native_session, Model.native_contexts
        assert Model.native_contexts[-1]["binding"]["boardID"] == native_board, Model.native_contexts
        native_request(f"/{native_board}/ask/{thread_id}/close", "POST", {})
        wb("session_activity_end", {"sessionId": native_board, "activityId": native_activity})
        print("PASS native Whiteboard Chat → real opencode acp → same-board MCP edit and saved-conversation reopen", flush=True)
        assert not Model.errors, Model.errors
    finally:
        for process in reversed(processes):
            stop(process)
        for log in logs:
            log.close()
        host_log = root / "opencode.log"
        if host_log.exists():
            host_log.write_text("\n".join("server password <REDACTED>" if line.startswith("server password ") else line
                                         for line in host_log.read_text().splitlines()) + "\n")
        model.shutdown()
        model.server_close()
        print("Isolated servers stopped; no global config or personal boards modified.", flush=True)


if __name__ == "__main__":
    main()
