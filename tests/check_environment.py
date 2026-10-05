"""Compare Unix configuration with fetched origin/main without bootstrapping plugins."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = (
    ".wezterm.lua", "nvim/init.lua", "nvim/lua/config/options.lua",
    "nvim/lua/plugins/CopilotChat.lua", "nvim/lua/plugins/yankclip.lua",
)


def main():
    git, nvim = shutil.which("git"), shutil.which("nvim")
    if not git or not nvim:
        raise SystemExit("Git and Neovim must be on PATH.")
    with tempfile.TemporaryDirectory(prefix="dotfiles-main-") as temporary:
        for name in FILES:
            target = Path(temporary) / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(subprocess.check_output([git, "show", "origin/main:" + name], cwd=ROOT))
        env = os.environ.copy()
        env["DOTFILES_BASELINE"] = temporary
        return subprocess.run(
            [nvim, "--headless", "-u", "NONE", "-i", "NONE", "-l", "tests/environment-isolation.lua"],
            cwd=ROOT, env=env, check=False,
        ).returncode


if __name__ == "__main__":
    raise SystemExit(main())
