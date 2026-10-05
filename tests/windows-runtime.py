"""Offline startup of a copied PR config with copied installed plugins; no host links."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    if os.name != "nt":
        raise SystemExit("Native Windows is required.")
    plugins = Path(os.environ["LOCALAPPDATA"]) / "nvim-data" / "lazy"
    if not (plugins / "lazy.nvim").is_dir():
        raise SystemExit("Existing plugins are required; this test never downloads them.")
    with tempfile.TemporaryDirectory(prefix="dotfiles-runtime-") as temporary:
        fixture = Path(temporary)
        shutil.copytree(ROOT / "nvim", fixture / "nvim")
        shutil.copy2(ROOT / "environment.lua", fixture / "environment.lua")
        shutil.copytree(plugins, fixture / "data" / "nvim-data" / "lazy")
        # Test-only host selection, using the common writer on a temporary repository.
        import importlib.util
        spec = importlib.util.spec_from_file_location("registration", ROOT / "scripts/environment.py")
        registration = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(registration)
        registration.register(fixture, "windows-powershell")
        env = os.environ.copy()
        env.pop("NVIM_APPNAME", None)
        for kind in ("DATA", "CACHE", "STATE"):
            env["XDG_" + kind + "_HOME"] = str(fixture / kind.lower())
        env["XDG_CONFIG_HOME"] = str(fixture)
        env["NVIM_LOG_FILE"] = str(fixture / "nvim.log")
        sample = fixture / "sample.md"
        sample.write_text("# Offline validation\n", encoding="utf-8")
        before = (fixture / "nvim/lazy-lock.json").read_bytes()
        setup = (
            "local lazy=require('lazy'); local original=lazy.setup; "
            "lazy.setup=function(opts) opts.install={missing=false}; "
            "opts.checker={enabled=false}; opts.change_detection={enabled=false}; "
            "opts.pkg={enabled=false}; opts.rocks={enabled=false}; "
            "opts.spec[#opts.spec+1]={'mason.nvim',config=function(_,o) require('mason').setup(o) end}; "
            "opts.spec[#opts.spec+1]={'mason-lspconfig.nvim',opts=function(_,o) "
            "o.ensure_installed={}; o.automatic_installation=false end}; "
            "opts.spec[#opts.spec+1]={'nvim-treesitter',opts=function(_,o) "
            "o.ensure_installed={}; o.auto_install=false end}; return original(opts) end"
        )
        lazy_path = (fixture / "data/nvim-data/lazy/lazy.nvim").as_posix()
        command = [shutil.which("nvim"), "--headless", "-i", "NONE",
                   "--cmd", "lua vim.opt.rtp:prepend(" + repr(lazy_path) + "); " + setup,
                   "-u", str(fixture / "nvim/init.lua"), str(sample),
                   "-S", str(ROOT / "tests/windows-runtime.lua")]
        result = subprocess.run(command, env=env, cwd=fixture, timeout=90, check=False)
        if before != (fixture / "nvim/lazy-lock.json").read_bytes():
            raise SystemExit("Startup changed the copied lockfile.")
        return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
