#!/usr/bin/env python3
"""Host-local environment registration. Never install tools or change app settings."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import platform
import shutil
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
ENVIRONMENTS = ("macos", "windows-wsl", "windows-powershell", "linux")


class EnvironmentError(ValueError):
    pass


def detect_environment():
    system = platform.system()
    if system == "Darwin":
        return "macos"
    if system == "Windows":
        return "windows-powershell"
    if system == "Linux":
        kernel = (platform.release() + " " + platform.version()).lower()
        wsl = os.environ.get("WSL_INTEROP") or os.environ.get("WSL_DISTRO_NAME") or "microsoft" in kernel
        return "windows-wsl" if wsl else "linux"
    raise EnvironmentError("Unsupported or unknown platform: " + system)


def host_name():
    host = platform.node()
    if not host:
        raise EnvironmentError("Cannot determine the local host name.")
    return host


def state_path(repo):
    local = Path(repo) / ".local"
    path = local / "environment.json"
    if local.is_symlink() or path.is_symlink():
        raise EnvironmentError("Local environment state must not use symbolic links.")
    if local.resolve() != Path(repo).resolve() / ".local":
        raise EnvironmentError("Local environment state must remain inside this checkout.")
    return path


def read_selection(repo):
    path = state_path(repo)
    if not path.exists():
        return None
    try:
        state = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, ValueError) as error:
        raise EnvironmentError("Invalid .local/environment.json; review it before registering.") from error
    if not isinstance(state, dict):
        raise EnvironmentError("Environment state must be a JSON object.")
    # Accept the initial Windows PR's unversioned records, without silently upgrading them.
    version = state.get("schemaVersion", 1)
    if type(version) is not int or version != 1:
        raise EnvironmentError("Unsupported environment state schema.")
    if state.get("environment") not in ENVIRONMENTS:
        raise EnvironmentError("Unknown saved environment.")
    if not isinstance(state.get("host"), str) or not state["host"]:
        raise EnvironmentError("Missing saved host identity.")
    if state.get("approved") is not True:
        raise EnvironmentError("Saved selection is not explicitly approved.")
    return state


def require_selection(repo, environment):
    state = read_selection(repo)
    if not state or state["host"].casefold() != host_name().casefold() or state["environment"] != environment:
        raise EnvironmentError("No matching approved local selection. Register the environment explicitly first.")
    return state


def check_target(environment, adoption=False):
    detected = detect_environment()
    # Windows can select WSL for future setup, but adoption must inspect inside WSL.
    allowed = {detected}
    if detected == "windows-powershell" and not adoption:
        allowed.add("windows-wsl")
    if environment not in allowed:
        raise EnvironmentError("Selected environment does not match this process. Run the command in the target environment.")


def inspect_existing(repo, environment):
    check_target(environment, adoption=True)
    repo = Path(repo).resolve()
    home = Path.home()
    config_home = os.environ.get("XDG_CONFIG_HOME")
    if config_home:
        config_home = Path(config_home)
        if not config_home.is_absolute():
            raise EnvironmentError("XDG_CONFIG_HOME must be an absolute directory.")
    elif environment == "windows-powershell":
        value = os.environ.get("LOCALAPPDATA")
        if not value or not Path(value).is_absolute():
            raise EnvironmentError("LOCALAPPDATA must be an absolute directory.")
        config_home = Path(value)
    else:
        config_home = home / ".config"
    app_name = os.environ.get("NVIM_APPNAME", "nvim")
    if Path(app_name).name != app_name or app_name in ("", ".", ".."):
        raise EnvironmentError("NVIM_APPNAME must be a directory name.")
    nvim = config_home / app_name
    candidates = (home / ".wezterm.lua", Path(os.environ.get("XDG_CONFIG_HOME", str(home / ".config"))) / "wezterm/wezterm.lua")
    wezterm = next((path for path in candidates if path.exists()), candidates[0])
    checks = []
    for app, target, source in (("nvim", nvim, repo / "nvim"), ("wezterm", wezterm, repo / ".wezterm.lua")):
        status = "missing"
        if target.exists():
            status = "linked" if target.resolve() == source.resolve() else "existing-unverified"
            if app == "wezterm" and status != "linked" and target.is_file():
                try:
                    text = target.read_text(encoding="utf-8-sig")
                    reference = str(source).replace("\\", "/").replace("'", "\\'")
                    if reference in text and "dofile(source)" in text:
                        status = "loader-reference"
                except (OSError, UnicodeError):
                    status = "unreadable"
        checks.append({"application": app, "target": str(target), "expectedSource": str(source), "status": status})
    commands = ("git", "nvim", "wezterm") + (("pwsh",) if environment == "windows-powershell" else ())
    return {"environment": environment, "configuration": checks, "tools": {name: bool(shutil.which(name)) for name in commands},
            "note": "Read-only inventory; missing tools or independent settings are not modified. WSL inspects guest paths only."}


def register(repo, environment, mode="new", replace_invalid=False):
    check_target(environment, adoption=mode == "adopt-existing")
    inspection = inspect_existing(repo, environment) if mode == "adopt-existing" else None
    path = state_path(repo)
    try:
        previous = read_selection(repo)
    except EnvironmentError:
        if not replace_invalid:
            raise
        previous = None
    host = host_name()
    if previous and previous["host"].casefold() == host.casefold() and previous["environment"] == environment:
        return {"result": "reused", "selection": previous, "inspection": inspection}
    state = {"schemaVersion": 1, "environment": environment, "host": host, "approved": True,
             "approvedAt": datetime.now(timezone.utc).isoformat(), "approvalSource": "explicit --environment",
             "registrationMode": mode}
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if path.exists():
        backup = path.with_name(path.name + ".backup-" + uuid.uuid4().hex)
        shutil.copy2(path, backup)
    descriptor, temporary = tempfile.mkstemp(prefix="environment-", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as file:
            json.dump(state, file, indent=2, ensure_ascii=False)
            file.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return {"result": "saved", "selection": state, "inspection": inspection}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("status", help="Read detected environment and saved choice without changing anything.")
    check = commands.add_parser("check", help="Inspect existing tool/configuration paths; no changes.")
    check.add_argument("--environment", choices=ENVIRONMENTS)
    for name in ("select", "adopt-existing"):
        command = commands.add_parser(name, help="Explicitly record a choice; never install or link settings.")
        command.add_argument("--environment", choices=ENVIRONMENTS, required=True)
        command.add_argument("--replace-invalid", action="store_true", help="Back up and replace an invalid local record explicitly.")
    require = commands.add_parser("require", help="Installer guard: require an existing host/environment approval.")
    require.add_argument("--environment", choices=ENVIRONMENTS, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "status":
            state = read_selection(ROOT)
            output = {"detected": detect_environment(), "selection": state,
                      "hostMatches": bool(state and state["host"].casefold() == host_name().casefold())}
        elif args.command == "check":
            state = read_selection(ROOT)
            saved = state["environment"] if state and state["host"].casefold() == host_name().casefold() else None
            output = inspect_existing(ROOT, args.environment or saved or detect_environment())
        elif args.command == "require":
            check_target(args.environment)
            output = require_selection(ROOT, args.environment)
        else:
            output = register(ROOT, args.environment, "adopt-existing" if args.command == "adopt-existing" else "new", args.replace_invalid)
        print(json.dumps(output, indent=2, ensure_ascii=False))
        return 0
    except (EnvironmentError, OSError) as error:
        print("Environment registration failed: " + str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
