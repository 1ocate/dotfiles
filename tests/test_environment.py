"""Four-environment registration and adoption checks; no real host changes."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("environment", Path(__file__).resolve().parents[1] / "scripts/environment.py")
env = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(env)


class EnvironmentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo"
        self.home = Path(self.temp.name) / "home"
        self.root.mkdir()
        self.home.mkdir()
        (self.root / "nvim").mkdir()
        (self.root / ".wezterm.lua").write_text("return {}")
        self.addCleanup(patch.stopall)
        patch.object(env.platform, "node", return_value="fixture-host").start()
        patch.object(env.Path, "home", return_value=self.home).start()
        patch.dict(os.environ, {}, clear=True).start()
        patch.object(env.shutil, "which", return_value=None).start()
        patch.object(env, "ROOT", self.root).start()

    def runtime(self, system, release="generic"):
        patch.object(env.platform, "system", return_value=system).start()
        patch.object(env.platform, "release", return_value=release).start()
        patch.object(env.platform, "version", return_value="generic").start()

    def test_detection(self):
        for system, release, expected in (("Darwin", "generic", "macos"), ("Windows", "generic", "windows-powershell"),
                                          ("Linux", "generic", "linux"), ("Linux", "microsoft-standard-WSL2", "windows-wsl")):
            with patch.object(env.platform, "system", return_value=system), patch.object(env.platform, "release", return_value=release), patch.object(env.platform, "version", return_value="generic"):
                self.assertEqual(env.detect_environment(), expected)
        self.runtime("Linux")
        with patch.dict(os.environ, {"WSL_DISTRO_NAME": "fixture"}):
            self.assertEqual(env.detect_environment(), "windows-wsl")
        with patch.object(env.platform, "system", return_value="Other"):
            with self.assertRaises(env.EnvironmentError): env.detect_environment()

    def test_no_automatic_selection_or_status_write(self):
        self.runtime("Linux")
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(env.main(["status"]), 0)
            self.assertEqual(env.main(["check"]), 0)
        self.assertFalse((self.root / ".local").exists())
        with self.assertRaises(env.EnvironmentError): env.require_selection(self.root, "linux")
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            env.main(["select"])

    def test_register_all_environments_and_repeat(self):
        for selected, system, release in (("macos", "Darwin", "generic"), ("linux", "Linux", "generic"),
                                          ("windows-wsl", "Linux", "microsoft"), ("windows-powershell", "Windows", "generic")):
            with patch.object(env.platform, "system", return_value=system), patch.object(env.platform, "release", return_value=release), patch.object(env.platform, "version", return_value="generic"):
                env.register(self.root, selected)
                before = env.state_path(self.root).read_bytes()
                self.assertEqual(env.register(self.root, selected)["result"], "reused")
                self.assertEqual(before, env.state_path(self.root).read_bytes())
                self.assertEqual(env.require_selection(self.root, selected)["environment"], selected)

    def test_wrong_host_and_target_are_rejected(self):
        self.runtime("Linux")
        env.register(self.root, "linux")
        with patch.object(env.platform, "node", return_value="other-host"):
            with self.assertRaises(env.EnvironmentError): env.require_selection(self.root, "linux")
        with self.assertRaises(env.EnvironmentError): env.register(self.root, "macos")
        self.assertEqual(env.read_selection(self.root)["environment"], "linux")

    def test_wsl_choice_on_windows_is_not_adoption(self):
        self.runtime("Windows")
        env.register(self.root, "windows-wsl")
        with self.assertRaises(env.EnvironmentError): env.register(self.root, "windows-wsl", mode="adopt-existing")
        with self.assertRaises(env.EnvironmentError): env.require_selection(self.root, "windows-powershell")

    def test_adoption_preserves_existing_settings_for_all_environments(self):
        config = self.home / "config"
        config.mkdir()
        (config / "nvim").mkdir()
        init = config / "nvim/init.lua"
        init.write_text("-- existing independent configuration")
        wezterm = self.home / ".wezterm.lua"
        wezterm.write_text("local source = '" + str(self.root / ".wezterm.lua").replace("\\", "/") + "'\nreturn dofile(source)")
        before = {init: init.read_bytes(), wezterm: wezterm.read_bytes()}
        for selected, system, release in (("macos", "Darwin", "generic"), ("linux", "Linux", "generic"),
                                          ("windows-wsl", "Linux", "microsoft"), ("windows-powershell", "Windows", "generic")):
            with patch.object(env.platform, "system", return_value=system), patch.object(env.platform, "release", return_value=release), patch.object(env.platform, "version", return_value="generic"), patch.dict(os.environ, {"XDG_CONFIG_HOME": str(config)}):
                result = env.register(self.root, selected, mode="adopt-existing")
                self.assertEqual(result["selection"]["registrationMode"], "adopt-existing")
                self.assertEqual(result["inspection"]["configuration"][0]["status"], "existing-unverified")
                self.assertEqual(result["inspection"]["configuration"][1]["status"], "loader-reference")
                self.assertFalse(any(result["inspection"]["tools"].values()))
                self.assertEqual(before, {path: path.read_bytes() for path in before})

    def test_invalid_state_requires_explicit_replacement_and_backup(self):
        self.runtime("Linux")
        path = env.state_path(self.root)
        path.parent.mkdir()
        path.write_bytes(b"invalid-state")
        with self.assertRaises(env.EnvironmentError): env.register(self.root, "linux")
        self.assertEqual(path.read_bytes(), b"invalid-state")
        env.register(self.root, "linux", replace_invalid=True)
        backup = next(path.parent.glob("environment.json.backup-*"))
        self.assertEqual(backup.read_bytes(), b"invalid-state")
        self.assertEqual(env.read_selection(self.root)["environment"], "linux")

    def test_schema_and_approval_types(self):
        self.runtime("Linux")
        env.register(self.root, "linux")
        path = env.state_path(self.root)
        valid = json.loads(path.read_text())
        for changes in ({"approved": "true"}, {"schemaVersion": True}, {"schemaVersion": 2}, {"environment": "windows"}):
            path.write_text(json.dumps(dict(valid, **changes)))
            with self.assertRaises(env.EnvironmentError): env.read_selection(self.root)
        # Compatibility with the initial Windows branch's unversioned record.
        valid.pop("schemaVersion")
        path.write_text(json.dumps(valid))
        self.assertEqual(env.require_selection(self.root, "linux")["environment"], "linux")


if __name__ == "__main__":
    unittest.main()
