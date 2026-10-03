"""Credential wrapper checks using dummy tokens; no network or real credentials."""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


class GitHubLocalTests(unittest.TestCase):
    def setUp(self):
        script = Path(__file__).resolve().parents[1] / "scripts" / "gh-local.py"
        spec = importlib.util.spec_from_file_location("gh_local", script)
        self.wrapper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.wrapper)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.wrapper.ROOT = Path(self.temp.name)
        self.local = self.wrapper.ROOT / ".local"
        self.local.mkdir()
        self.token = self.local / "gh-token"

    def invoke(self, args):
        output = io.StringIO()
        with contextlib.redirect_stderr(output):
            result = self.wrapper.main(args)
        return result, output.getvalue()

    def write_token(self, value="fixture-token"):
        self.token.write_text(value, encoding="utf-8")
        self.token.chmod(0o600)

    def test_missing_empty_and_multiple_tokens(self):
        self.assertEqual(self.invoke(["pr", "list"])[0], 2)
        for value in ("", "fixture-token\nsecond-token"):
            self.write_token(value)
            result, output = self.invoke(["pr", "list"])
            self.assertEqual(result, 2)
            self.assertNotIn("fixture-token", output)

    def test_invalid_encoding_is_not_printed(self):
        self.token.write_bytes(b"fixture-token\xff")
        self.token.chmod(0o600)
        result, output = self.invoke(["pr", "list"])
        self.assertEqual(result, 2)
        self.assertEqual(output.strip(), "Cannot read .local/gh-token.")

    @unittest.skipIf(os.name == "nt", "POSIX permissions do not validate Windows ACLs")
    def test_permissions_and_symlink(self):
        self.write_token()
        self.token.chmod(0o644)
        self.assertEqual(self.invoke(["pr", "list"])[0], 2)
        destination = self.local / "fixture"
        self.token.rename(destination)
        self.token.symlink_to(destination)
        self.assertEqual(self.invoke(["pr", "list"])[0], 2)

    def test_auth_and_extensions_are_blocked(self):
        for command in ("auth", "extension"):
            self.assertEqual(self.invoke([command, "list"])[0], 2)

    def test_missing_cli(self):
        self.write_token()
        with patch.object(self.wrapper.shutil, "which", return_value=None):
            self.assertEqual(self.invoke(["pr", "list"])[0], 2)

    def test_environment_and_exit_status(self):
        self.write_token("fixture-token\n")
        inherited = {"GH_TOKEN": "old", "GITHUB_TOKEN": "old", "GH_DEBUG": "api",
                     "GH_REPO": "other/repo", "GH_ENTERPRISE_TOKEN": "old"}
        with patch.dict(os.environ, inherited), \
                patch.object(self.wrapper.shutil, "which", return_value="/fixture/gh"), \
                patch.object(self.wrapper.subprocess, "run") as run:
            run.return_value.returncode = 7
            self.assertEqual(self.invoke(["pr", "list"])[0], 7)
            args, options = run.call_args
            self.assertEqual(args[0], ["/fixture/gh", "pr", "list"])
            self.assertNotIn("fixture-token", str(args))
            self.assertEqual(options["cwd"], self.wrapper.ROOT)
            self.assertEqual(options["env"]["GH_TOKEN"], "fixture-token")
            self.assertEqual(options["env"]["GH_REPO"], "1ocate/dotfiles")
            self.assertEqual(options["env"]["GH_CONFIG_DIR"], str(self.local / "gh"))
            for key in ("GITHUB_TOKEN", "GH_DEBUG", "GH_ENTERPRISE_TOKEN"):
                self.assertNotIn(key, options["env"])
            self.assertEqual(os.environ["GH_TOKEN"], "old")


if __name__ == "__main__":
    unittest.main()
