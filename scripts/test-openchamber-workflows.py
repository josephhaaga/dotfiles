#!/usr/bin/env python3
"""Offline unit and loopback-only HTTP tests; no deployed files or live APIs."""
import contextlib
import copy
import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("workflows", str(ROOT / "home/dot_local/bin/executable_openchamber-workflows"))
spec = importlib.util.spec_from_loader(loader.name, loader)
workflows = importlib.util.module_from_spec(spec)
loader.exec_module(workflows)
DEFAULTS = ROOT / "home/dot_config/dotfiles/openchamber-workflow-defaults.json"


class MockClient:
    def __init__(self, current=None, version="2.1.1", drop=False):
        self.current = current or {}
        self.version = version
        self.drop = drop
        self.calls = []

    def request(self, method, path, body=None):
        self.calls.append((method, path, body))
        if path == "/api/version":
            return {"openchamberVersion": self.version}
        if method == "PUT" and not self.drop:
            self.current.update(body)
        return copy.deepcopy(self.current)


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.document = workflows.load_defaults(DEFAULTS)
        self.output = io.StringIO()
        self.redirect = contextlib.redirect_stdout(self.output)
        self.redirect.__enter__()

    def tearDown(self):
        self.redirect.__exit__(None, None, None)

    def test_safe_shipped_defaults(self):
        settings = self.document["settings"]
        self.assertIs(settings["sessionGoalEnabled"], False)
        self.assertIs(settings["sessionGoalDefaultBudgetEnabled"], True)
        self.assertEqual(settings["permissionDefaultMode"], "ask")
        self.assertEqual(settings["sessionGoalMaxAutoTurns"], 1)

    def test_overlay_rejects_unknown_fields_and_invalid_types(self):
        for key, value in [("desktopUiPassword", "fixture"), ("sessionWorkEnabled", 1),
                           ("sessionGoalMaxAutoTurns", 201), ("sessionGoalDefaultBudget", 0),
                           ("notificationMode", "sometimes"), ("permissionDefaultMode", "bad")]:
            with self.subTest(key=key), tempfile.TemporaryDirectory() as directory:
                document = copy.deepcopy(self.document)
                document["settings"][key] = value
                file = Path(directory) / "defaults.json"
                file.write_text(json.dumps(document))
                with self.assertRaises(workflows.WorkflowError):
                    workflows.load_defaults(file)

    def test_version_failure_precedes_settings_read(self):
        for version in ["2.2.0", None, 2]:
            client = MockClient(version=version)
            with self.assertRaises(workflows.WorkflowError):
                workflows.reconcile(client, self.document, "apply")
            self.assertEqual(len(client.calls), 1)

    def test_dry_run_and_verify_never_put_or_print_runtime_values(self):
        for mode, status in [("dry-run", 0), ("verify", 1)]:
            client = MockClient({"desktopUiPassword": "private-fixture"})
            self.assertEqual(workflows.reconcile(client, self.document, mode), status)
            self.assertFalse(any(call[0] == "PUT" for call in client.calls))
            self.assertNotIn("private-fixture", self.output.getvalue())

    def test_apply_only_delta_preserves_unrelated_and_is_idempotent(self):
        current = {"themeId": "custom", "desktopUiPassword": "private-fixture",
                   "projects": [{"id": "fixture"}], "sessionWorkEnabled": True}
        client = MockClient(copy.deepcopy(current))
        self.assertEqual(workflows.reconcile(client, self.document, "apply"), 0)
        writes = [call[2] for call in client.calls if call[0] == "PUT"]
        self.assertEqual(len(writes), 1)
        self.assertNotIn("sessionWorkEnabled", writes[0])
        self.assertTrue(set(writes[0]) <= set(self.document["settings"]))
        for key in ["themeId", "desktopUiPassword", "projects"]:
            self.assertEqual(client.current[key], current[key])
        workflows.reconcile(client, self.document, "apply")
        self.assertEqual(sum(call[0] == "PUT" for call in client.calls), 1)

    def test_silent_api_drops_fail_verification(self):
        with self.assertRaisesRegex(workflows.WorkflowError, "verification failed"):
            workflows.reconcile(MockClient(drop=True), self.document, "apply")

    def test_comparison_does_not_confuse_boolean_and_integer(self):
        self.assertEqual(workflows.differences({"x": 1}, {"x": True}), {"x": True})

    def test_endpoint_restrictions(self):
        for url in ["http://remote.example", "https://user:password@example.com", "https://example.com/api",
                    "https://example.com?token=secret", "https://example.com#fragment", "file:///tmp/x",
                    "http://localhost:bad", "https://example.com\\@evil.example"]:
            with self.subTest(url=url), self.assertRaises(workflows.WorkflowError):
                workflows.validate_origin(url)
        for url in ["http://127.0.0.1:3000", "http://[::1]:3000", "https://example.com/"]:
            self.assertEqual(workflows.validate_origin(url), url.rstrip("/"))

    def test_auth_file_permissions_origin_and_header_injection(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / "auth.json"
            file.write_text(json.dumps({"origin": "http://127.0.0.1:3000", "cookie": "fixture=value"}))
            file.chmod(0o600)
            self.assertEqual(workflows.read_cookie(file, "http://127.0.0.1:3000"), "fixture=value")
            with self.assertRaises(workflows.WorkflowError):
                workflows.read_cookie(file, "https://other.example")
            file.chmod(0o644)
            with self.assertRaises(workflows.WorkflowError):
                workflows.read_cookie(file, "http://127.0.0.1:3000")
            file.chmod(0o600)
            file.write_text(json.dumps({"origin": "http://127.0.0.1:3000", "cookie": "x=y\r\nInjected: z"}))
            with self.assertRaises(workflows.WorkflowError):
                workflows.read_cookie(file, "http://127.0.0.1:3000")

    def test_offline_default_and_network_requires_url(self):
        self.assertEqual(workflows.main(["--defaults", str(DEFAULTS)]), 0)
        for mode in ["--apply", "--verify"]:
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(workflows.main([mode, "--defaults", str(DEFAULTS)]), 2)

    def test_http_mock_auth_delta_and_redirect_refusal(self):
        calls = []
        state = {"themeId": "custom"}
        desired = self.document

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_GET(self):
                calls.append((self.command, self.path, self.headers.get("Cookie")))
                if self.path == "/redirect":
                    self.send_response(302)
                    self.send_header("Location", "/must-not-receive-cookie")
                    self.end_headers()
                    return
                if self.headers.get("Cookie") != "fixture=value":
                    self.send_response(401)
                    self.end_headers()
                    return
                body = {"openchamberVersion": "2.1.1"} if self.path == "/api/version" else state
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps(body).encode())

            def do_PUT(self):
                calls.append((self.command, self.path, self.headers.get("Cookie")))
                delta = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                if not set(delta) <= set(desired["settings"]):
                    self.send_response(400)
                    self.end_headers()
                    return
                state.update(delta)
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps(state).encode())

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            origin = f"http://127.0.0.1:{server.server_port}"
            client = workflows.Client(origin, "fixture=value")
            self.assertEqual(workflows.reconcile(client, desired, "apply"), 0)
            self.assertEqual(state["themeId"], "custom")
            with self.assertRaises(workflows.WorkflowError):
                client.request("GET", "/redirect")
            self.assertFalse(any(call[1] == "/must-not-receive-cookie" for call in calls))
            with self.assertRaisesRegex(workflows.WorkflowError, "HTTP 401"):
                workflows.Client(origin, "fixture=wrong").request("GET", "/api/version")
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


if __name__ == "__main__":
    unittest.main()
