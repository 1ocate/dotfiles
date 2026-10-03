#!/usr/bin/env python3
"""Run GitHub CLI with repository-local credentials, without a shell."""
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main(args):
    if not args:
        print("Usage: python3 scripts/gh-local.py <gh arguments>", file=sys.stderr)
        return 2
    if args[0] in {"auth", "extension"}:
        print("auth/extension commands are disabled; manage the local token file directly.", file=sys.stderr)
        return 2
    token_path = ROOT / ".local" / "gh-token"
    try:
        if token_path.is_symlink() or not token_path.is_file():
            raise ValueError("Create .local/gh-token as a regular file containing one token.")
        if os.name != "nt" and stat.S_IMODE(token_path.stat().st_mode) & 0o077:
            raise ValueError("Restrict .local/gh-token permissions with chmod 600.")
        token = token_path.read_text(encoding="utf-8").strip()
        if not token or any(char.isspace() for char in token):
            raise ValueError("Set one nonempty token in .local/gh-token; do not paste it into chat.")
    except (OSError, UnicodeError, ValueError) as error:
        # Do not print file contents or exception details that may contain them.
        message = str(error) if type(error) is ValueError else "Cannot read .local/gh-token."
        print(message, file=sys.stderr)
        return 2
    gh = shutil.which("gh")
    if gh is None:
        print("Install GitHub CLI (gh) and add it to PATH.", file=sys.stderr)
        return 2
    config_dir = ROOT / ".local" / "gh"
    config_dir.mkdir(mode=0o700, exist_ok=True)
    env = os.environ.copy()
    for key in ("GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN", "GH_DEBUG", "DEBUG", "GH_REPO", "GH_HOST"):
        env.pop(key, None)
    env.update(GH_TOKEN=token, GH_CONFIG_DIR=str(config_dir), GH_HOST="github.com", GH_REPO="1ocate/dotfiles",
               GH_PROMPT_DISABLED="1", GH_NO_UPDATE_NOTIFIER="1")
    return subprocess.run([gh, *args], cwd=ROOT, env=env, check=False).returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
