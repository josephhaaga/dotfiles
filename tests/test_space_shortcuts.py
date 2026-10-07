"""No macOS mutations: yabai and open are mocked in all focus/routing tests."""
import importlib.util
import http.client
import json
from pathlib import Path
import tempfile
import re
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("space_shortcuts", ROOT / "home/dot_local/lib/dotfiles/space_shortcuts.py")
lab = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(lab)


def plan():
    return {"version": 1, "spaces": [{"id": "build", "name": "Build", "index": 1, "key": "alt + ctrl + cmd - 1"}],
            "apps": [{"id": "terminal", "app": "Ghostty", "space": "build", "key": "alt + ctrl - t", "title": "", "route": False}]}


class ValidationTests(unittest.TestCase):
    def test_normalize(self):
        self.assertEqual(lab.validate(plan())["apps"][0]["key"], "ctrl + alt - t")

    def test_invalid_input(self):
        for value in (None, [], {}, {"version": 2}):
            with self.subTest(value=value), self.assertRaises(ValueError):
                lab.validate(value)

    def test_duplicate_keys(self):
        p = plan()
        p["apps"][0]["key"] = "ctrl + alt + cmd - 1"
        with self.assertRaisesRegex(ValueError, "Two proposed"):
            lab.validate(p)

    def test_bad_shortcuts(self):
        for key in ("alt - t; touch pwned", "ctrl + ctrl - t", "fn - t", "t", "cmd - F1"):
            with self.subTest(key=key), self.assertRaises(ValueError):
                lab.shortcut(key)

    def test_invalid_ids_and_references(self):
        for field, value in (("id", "../escape"), ("space", "missing"), ("route", "true"), ("app", "Ghostty\ncommand")):
            p = plan()
            p["apps"][0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                lab.validate(p)

    def test_duplicate_indices(self):
        p = plan()
        p["spaces"].append({"id": "browse", "name": "Browse", "index": 1, "key": ""})
        with self.assertRaises(ValueError):
            lab.validate(p)

    def test_conflicts_normalize_modifier_order(self):
        skhd = 'alt + ctrl - t : existing\n' + lab.BEGIN + '\n' + lab.END
        with self.assertRaisesRegex(ValueError, "already used"):
            lab.generate(lab.validate(plan()), skhd)

    def test_generated_block_preserves_other_bindings(self):
        skhd = 'alt - h : original\n' + lab.BEGIN + '\nold\n' + lab.END + '\n# tail\n'
        output = lab.generate(lab.validate(plan()), skhd)
        self.assertTrue(output.startswith('alt - h : original\n'))
        self.assertTrue(output.endswith('\n# tail\n'))
        self.assertIn('"$HOME/.local/bin/space-shortcuts" focus terminal', output)
        self.assertNotIn('\nold\n', output)

    def test_reject_missing_or_duplicate_markers(self):
        for value in ('', lab.BEGIN + lab.BEGIN + lab.END, lab.END + lab.BEGIN):
            with self.assertRaises(ValueError):
                lab.outside_block(value)

    def test_existing_config_does_not_conflict_with_starter(self):
        skhd = (ROOT / "home/executable_dot_skhdrc").read_text()
        self.assertEqual(lab.conflicts(lab.validate(plan()), skhd), [])


class FocusTests(unittest.TestCase):
    @patch.object(lab, "run")
    @patch.object(lab, "query")
    def test_find_existing_window_anywhere(self, query, run):
        query.return_value = [{"id": 9, "app": "Ghostty", "space": 6, "title": "Work"}]
        self.assertIn("space 6", lab.focus(lab.validate(plan()), "terminal"))
        run.assert_called_once_with("yabai", "-m", "window", "--focus", "9")

    @patch.object(lab, "run")
    @patch.object(lab, "query", return_value=[])
    def test_open_absent_app_without_shell(self, _query, run):
        lab.focus(lab.validate(plan()), "terminal")
        run.assert_called_once_with("open", "-a", "Ghostty")

    @patch.object(lab, "run")
    @patch.object(lab, "query", return_value=[])
    def test_missing_filtered_window_never_launches(self, _query, run):
        p = plan()
        p["apps"][0]["title"] = "Project"
        with self.assertRaisesRegex(ValueError, "No Ghostty window matches"):
            lab.focus(lab.validate(p), "terminal")
        run.assert_not_called()

    @patch.object(lab, "run")
    @patch.object(lab, "query")
    def test_draft_uses_index_not_previous_label(self, query, run):
        query.return_value = [{"index": 1}, {"index": 5, "label": "spaceslab-build"}]
        lab.focus(lab.validate(plan()), "build", draft=True)
        run.assert_called_once_with("yabai", "-m", "space", "--focus", "1")

    @patch.object(lab, "query")
    def test_deployed_uses_label_after_renumbering(self, query):
        query.return_value = [{"index": 5, "label": "spaceslab-build"}]
        self.assertEqual(lab.target_space(lab.validate(plan()), "build"), 5)

    @patch.object(lab, "run")
    @patch.object(lab, "query", return_value=[{"index": 1, "is-native-fullscreen": True}])
    def test_fullscreen_test_rejected(self, _query, run):
        with self.assertRaisesRegex(ValueError, "does not exist"):
            lab.focus(lab.validate(plan()), "build", draft=True)
        run.assert_not_called()

    @patch.object(lab, "run")
    @patch.object(lab, "query")
    def test_restore_uses_rule_list_and_does_not_apply_existing_windows(self, query, run):
        query.return_value = [{"index": 1, "label": ""}]
        run.return_value = json.dumps([{"label": "spaceslab-old"}, {"label": "unrelated"}])
        p = plan()
        p["apps"][0]["route"] = True
        lab.restore(lab.validate(p))
        commands = [call.args for call in run.call_args_list]
        self.assertIn(("yabai", "-m", "rule", "--list"), commands)
        self.assertIn(("yabai", "-m", "rule", "--remove", "spaceslab-old"), commands)
        self.assertFalse(any("unrelated" in c or "--apply" in c or "window" in c for c in commands))
        self.assertTrue(any("--add" in c and "app=^Ghostty$" in c for c in commands))

    @patch.object(lab, "run", return_value="[]")
    @patch.object(lab, "query", return_value=[{"index": 1, "label": "spaceslab-old"}])
    def test_empty_plan_removes_only_tool_labels(self, _query, run):
        lab.restore({"version": 1, "spaces": [], "apps": []})
        self.assertIn(unittest.mock.call("yabai", "-m", "space", "1", "--label"), run.call_args_list)

    @patch.object(lab, "query")
    def test_inventory_omits_titles(self, query):
        query.side_effect = [[{"index": 1}], [{"space": 1, "app": "Ghostty", "title": "private"}]]
        result = lab.inventory()
        self.assertNotIn("private", json.dumps(result))
        self.assertEqual(result["spaces"][0]["apps"], ["Ghostty"])


class SourceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        (root / ".chezmoiroot").write_text("home\n")
        (root / "home/dot_config/yabai").mkdir(parents=True)
        self.config = root / "home/dot_config/yabai/space-shortcuts.json"
        self.config.write_text(json.dumps({"version": 1, "spaces": [], "apps": []}))
        self.skhd = root / "home/executable_dot_skhdrc"
        self.skhd.write_text("# original\n" + lab.BEGIN + "\n" + lab.END + "\n")
        self.skhd.chmod(0o755)
        self.source = lab.Source(root)

    def tearDown(self):
        self.tmp.cleanup()

    def test_save_updates_source_and_preserves_mode(self):
        before = self.source.revision()
        result = self.source.save(plan(), before)
        self.assertNotEqual(result["revision"], before)
        self.assertEqual(self.skhd.stat().st_mode & 0o777, 0o755)
        self.assertEqual(json.loads(self.config.read_text())["spaces"][0]["name"], "Build")

    def test_stale_revision_rejected_without_writes(self):
        before = self.source.revision()
        self.skhd.write_text(self.skhd.read_text() + "# external edit\n")
        old_config = self.config.read_text()
        with self.assertRaisesRegex(ValueError, "Source changed"):
            self.source.save(plan(), before)
        self.assertEqual(self.config.read_text(), old_config)

    def test_preview_does_not_write(self):
        revision = self.source.revision()
        self.source.preview(plan())
        self.assertEqual(self.source.revision(), revision)

    def test_posix_literal(self):
        self.assertEqual(lab.regex_literal("App (Work)+"), r"App \(Work\)\+")


class HttpTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        root = Path(cls.tmp.name)
        (root / ".chezmoiroot").write_text("home")
        config = root / "home/dot_config/yabai/space-shortcuts.json"
        config.parent.mkdir(parents=True)
        config.write_text(json.dumps({"version": 1, "spaces": [], "apps": []}))
        (root / "home/executable_dot_skhdrc").write_text(lab.BEGIN + "\n" + lab.END)
        html = root / "home/dot_local/share/yabai-spaces/index.html"
        html.parent.mkdir(parents=True)
        html.write_text("<html>__SPACES_TOKEN__</html>")
        cls.process = subprocess.Popen([sys.executable, SPEC.origin, "serve", "--source", str(root), "--no-open"],
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        line = cls.process.stdout.readline()
        cls.port = int(line.strip().rsplit(":", 1)[1])
        cls.host = f"127.0.0.1:{cls.port}"
        status, body = cls.request("GET", "/")
        if status != 200:
            raise RuntimeError(body)
        cls.token = re.search(r"<html>([^<]+)</html>", body)[1]

    @classmethod
    def tearDownClass(cls):
        cls.process.terminate()
        cls.process.communicate(timeout=5)
        cls.tmp.cleanup()

    @classmethod
    def request(cls, method, path, headers=None, body=None):
        conn = http.client.HTTPConnection("127.0.0.1", cls.port, timeout=5)
        conn.request(method, path, body=body, headers=headers or {})
        response = conn.getresponse()
        status, value = response.status, response.read().decode()
        conn.close()
        return status, value

    def test_api_requires_token(self):
        self.assertEqual(self.request("POST", "/api/preview", body="{}")[0], 403)

    def test_bad_host_is_rejected(self):
        self.assertEqual(self.request("GET", "/", {"Host": "evil.example"})[0], 403)

    def test_cross_origin_is_rejected(self):
        headers = {"Origin": "https://evil.example", "X-Spaces-Token": self.token}
        self.assertEqual(self.request("POST", "/api/preview", headers, "{}")[0], 403)

    def test_authenticated_preview(self):
        headers = {"Origin": f"http://{self.host}", "X-Spaces-Token": self.token}
        status, body = self.request("POST", "/api/preview", headers, json.dumps({"plan": plan()}))
        self.assertEqual(status, 200)
        self.assertIn("space-shortcuts", json.loads(body)["skhd"])

    def test_unknown_endpoint(self):
        self.assertEqual(self.request("GET", "/arbitrary/path")[0], 404)


if __name__ == "__main__":
    unittest.main()
