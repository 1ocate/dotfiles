"""Read-only device inventory. No shell, installer, state writes, or explicit network requests."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import re
import shutil
import sys

import environment as env

ROOT = Path(__file__).resolve().parents[1]
LABELS = {'present': '발견', 'reference-found': '참조 발견', 'missing': '누락',
          'mismatch': '불일치', 'unknown': '확인 필요', 'not-selected': '선택 안 함'}


def item(name, status, detail):
    return {'component': name, 'status': status, 'detail': detail, 'runtimeVerified': False}


def read_text(path, limit=2 * 1024 * 1024):
    if path.stat().st_size > limit:
        raise ValueError('File too large for inventory')
    raw = path.read_bytes()
    if raw.startswith((b'\xff\xfe', b'\xfe\xff')):
        return raw.decode('utf-16')
    return raw.decode('utf-8-sig')


def documents_directory():
    """CSIDL_PERSONAL follows Windows Documents redirection; never create it."""
    buffer = ctypes.create_unicode_buffer(32768)
    if ctypes.windll.shell32.SHGetFolderPathW(None, 5, None, 0, buffer) != 0:
        raise OSError('Documents lookup failed')
    path = Path(buffer.value)
    if not path.is_absolute():
        raise OSError('Documents path is not absolute')
    return path


def block_comment_start(line):
    """Find a block-comment token outside ordinary PowerShell string literals."""
    quote = None
    index = 0
    while index < len(line):
        char = line[index]
        if char == '`' and quote != "'":
            index += 2
            continue
        if quote:
            if char == quote:
                if quote == "'" and index + 1 < len(line) and line[index + 1] == "'":
                    index += 2
                    continue
                quote = None
        elif line.startswith('<#', index):
            return index
        elif char == '#':
            return -1
        elif char in ("'", '"'):
            quote = char
        index += 1
    return -1


def active_lines(text):
    """Conservative literal-reference inventory, not a PowerShell interpreter."""
    block = False
    here_end = None
    for line in text.splitlines():
        stripped = line.strip()
        if here_end:
            if stripped == here_end:
                here_end = None
            continue
        if block:
            if '#>' in stripped:
                block = False
            continue
        comment_index = block_comment_start(stripped)
        if comment_index >= 0:
            block = '#>' not in stripped[comment_index + 2:]
            if stripped[:comment_index].strip():
                yield stripped[:comment_index].strip()
            continue
        if stripped.startswith('#'):
            continue
        if re.search(r"@['\"]\s*$", stripped):
            here_end = "'@" if stripped.endswith("@'") else '"@'
            continue
        yield stripped


def literal_loaders(lines):
    pattern = re.compile(r"^\.\s+(?:'((?:[^']|'')*)'|\"([^\"]*)\")\s*(?:#.*)?$")
    for line in lines:
        match = pattern.match(line)
        if match:
            value = match[1].replace("''", "'") if match[1] is not None else match[2]
            # Double-quoted interpolation and relative CWD-dependent references are unknown.
            if (match[1] is not None or not re.search(r'[$`]', value)) and Path(value).is_absolute():
                yield Path(value)


def profile_checks(repo, documents):
    checks = []
    for shell in ('WindowsPowerShell', 'PowerShell'):
        prefix = 'profile.' + shell
        path = documents / shell / 'Microsoft.PowerShell_profile.ps1'
        try:
            text = read_text(path)
        except FileNotFoundError:
            checks.append(item(prefix, 'missing', 'CurrentUserCurrentHost profile is absent; other profile scopes not inspected.'))
            continue
        except (OSError, UnicodeError, ValueError, RuntimeError):
            checks.append(item(prefix, 'unknown', 'Profile cannot be safely read; it was not executed.'))
            continue
        checks.append(item(prefix, 'present', 'Only CurrentUserCurrentHost inspected; earlier returns/conditions/overrides and loaded sessions are unverified.'))
        lines = list(active_lines(text))
        loaders = list(literal_loaders(lines))
        for component, filename in (('aliases', 'aliases.ps1'), ('git', 'git-completion.ps1'),
                                    ('mux', 'psmux.ps1'), ('tab', 'tab-completion.ps1')):
            source = repo / 'powershell' / filename
            candidates = [p for p in loaders if p.name.casefold() == filename.casefold()]
            matched = [p for p in candidates if p.resolve() == source.resolve()]
            if not source.is_file():
                status, reason = 'missing', 'Runtime source is absent in this checkout.'
            elif len(candidates) > 1:
                status, reason = 'mismatch', 'Multiple literal loaders; inspect duplicate or competing initialization.'
            elif matched:
                status, reason = 'reference-found', 'Literal loader references this checkout; startup execution is unverified.'
            elif candidates:
                status, reason = 'mismatch', 'Literal loader references another source.'
            elif any(filename in line for line in lines):
                status, reason = 'unknown', 'Dynamic/complex reference requires manual inspection.'
            else:
                status, reason = 'missing', 'No recognized literal loader; other profile scopes may supply it.'
            checks.append(item(prefix + '.' + component, status, reason))
            if component == 'tab' and status == 'reference-found':
                for child in ('ssh-completion.ps1', 'ssh-fzf.ps1', 'history-fzf.ps1'):
                    child_path = repo / 'powershell' / child
                    checks.append(item(prefix + '.' + child, 'present' if child_path.is_file() else 'missing',
                                       'Tab runtime dependency file only; PSReadLine key binding is unverified.'))
        omp = [line for line in lines if re.match(r'^oh-my-posh\s+init\s+pwsh\b', line)]
        status, reason = 'missing', 'No recognized oh-my-posh initialization; arbitrary profile code is not evaluated.'
        if len(omp) > 1:
            status, reason = 'mismatch', 'Multiple oh-my-posh initializers.'
        elif omp:
            match = re.search(r"--config\s+(?:'((?:[^']|'')*)'|\"([^\"]*)\"|(\S+))", omp[0])
            if not match:
                status = 'reference-found' if shell == 'WindowsPowerShell' else 'mismatch'
                reason = 'Default theme initializer; repository PS7 theme is not referenced.'
            else:
                value = next(group for group in match.groups() if group is not None).replace("''", "'")
                if re.search(r'[$`]', value) or not Path(value).is_absolute():
                    status, reason = 'unknown', 'Dynamic theme path is not evaluated.'
                elif Path(value).resolve() == (repo / 'powershell/prompt.omp.json').resolve():
                    status = 'reference-found' if Path(value).is_file() else 'missing'
                    reason = 'Repository theme reference only; OMP version/streaming/rendering unverified.'
                else:
                    status, reason = 'mismatch', 'Initializer references another theme.'
        checks.append(item(prefix + '.prompt', status, reason))
    manifest = documents / 'WindowsPowerShell/Modules/posh-git/1.1.0/posh-git.psd1'
    checks.append(item('posh-git.manifest', 'present' if manifest.is_file() else 'missing',
                       'Pinned manifest path only; module import was not attempted.'))
    return checks


def record_check(repo, filename, detected, host_free=False):
    path = repo / '.local' / filename
    name = 'record.' + filename
    try:
        local = repo / '.local'
        if local.is_symlink() or path.is_symlink() or local.resolve() != repo.resolve() / '.local':
            return item(name, 'unknown', 'Linked local record refused; no external record read.')
        data = json.loads(read_text(path, 256 * 1024))
    except FileNotFoundError:
        return item(name, 'missing', 'No progress record; this does not mean the component is uninstalled.')
    except (OSError, UnicodeError, ValueError, RuntimeError):
        return item(name, 'unknown', 'Unreadable or malformed progress record; no content is emitted.')
    if not isinstance(data, dict) or not isinstance(data.get('components'), dict):
        return item(name, 'unknown', 'Record shape is not recognized.')
    version = data.get('schemaVersion', 1)
    if type(version) is not int or version != 1:
        return item(name, 'unknown', 'Unsupported record schema.')
    if data.get('environment') != detected:
        return item(name, 'mismatch', 'Record environment differs; not current-device completion evidence.')
    if not host_free and (not isinstance(data.get('host'), str) or data['host'].casefold() != env.host_name().casefold()):
        return item(name, 'mismatch', 'Record host differs or is absent; not current-device completion evidence.')
    return item(name, 'present', 'Record structure matches (host-free aliases exception).' if host_free else
                'Record structure and host match; recorded completion is not independently verified.')


def mux_check(repo):
    path = repo / '.local/psmux.json'
    try:
        local = repo / '.local'
        if local.is_symlink() or path.is_symlink() or local.resolve() != repo.resolve() / '.local':
            raise ValueError('Linked feature record')
        data = json.loads(read_text(path, 256 * 1024))
    except FileNotFoundError:
        return item('mux.selection', 'unknown', 'No feature choice record; do not assume installation is requested.')
    except (OSError, UnicodeError, ValueError, RuntimeError):
        return item('mux.selection', 'unknown', 'Feature record is unreadable or malformed.')
    if not isinstance(data, dict) or type(data.get('schemaVersion')) is not int or data['schemaVersion'] != 1 or type(data.get('enabled')) is not bool:
        return item('mux.selection', 'unknown', 'Feature record shape is not recognized.')
    if not isinstance(data.get('host'), str) or data['host'].casefold() != env.host_name().casefold():
        return item('mux.selection', 'mismatch', 'Feature choice belongs to another host; not reused.')
    return item('mux.selection', 'present' if data['enabled'] else 'not-selected',
                'Local feature choice only; executable versions and live mux behavior are unverified.')


def collect(repo=ROOT):
    repo = Path(repo).resolve()
    if not (repo / 'scripts/environment.py').is_file():
        raise ValueError('Not a dotfiles source checkout')
    detected = env.detect_environment()
    checks = []
    try:
        selection = env.read_selection(repo)
        if not selection:
            status, reason = 'missing', 'No saved choice; read-only inventory is allowed and never records approval.'
        elif selection['host'].casefold() != env.host_name().casefold() or selection['environment'] != detected:
            status, reason = 'mismatch', 'Saved host/environment differs; do not reuse as approval.'
        else:
            status, reason = 'present', 'Approved choice matches this host and environment; installation is not implied.'
    except (env.EnvironmentError, OSError, RuntimeError):
        status, reason = 'unknown', 'Selection cannot be validated; no state was changed.'
    checks.append(item('environment.selection', status, reason))
    tools = ('git', 'nvim', 'wezterm')
    if detected == 'windows-powershell':
        tools += ('pwsh', 'fzf', 'oh-my-posh', 'k9s', 'kubectl')
    else:
        tools += ('fzf', 'tmux', 'fish', 'zsh')
    for tool in tools:
        checks.append(item('tool.' + tool, 'present' if shutil.which(tool) else 'missing',
                           'PATH discovery only; executable/version was not run. Missing optional tools do not request installation.'))
    try:
        inventory = env.inspect_existing(repo, detected)
        mapping = {'linked': 'reference-found', 'loader-reference': 'reference-found', 'missing': 'missing',
                   'existing-unverified': 'mismatch', 'unreadable': 'unknown'}
        for entry in inventory['configuration']:
            checks.append(item('config.' + entry['application'], mapping.get(entry['status'], 'unknown'),
                               'Static link/known loader inspection only: ' + entry['status']))
    except (env.EnvironmentError, OSError, RuntimeError, ValueError):
        checks.append(item('config.paths', 'unknown', 'Application paths cannot be inspected safely.'))
    checks.append(record_check(repo, 'setup-state.json', detected))
    if detected == 'windows-powershell':
        checks.append(record_check(repo, 'powershell-aliases.json', detected, host_free=True))
        try:
            documents = documents_directory()
            checks.extend(profile_checks(repo, documents))
        except (OSError, ValueError, AttributeError, RuntimeError):
            checks.append(item('profiles', 'unknown', 'Windows Documents lookup failed; no home-path guess was used.'))
        localapp = os.environ.get('LOCALAPPDATA', '')
        if not localapp or not Path(localapp).is_absolute():
            checks.append(item('windows-terminal', 'unknown', 'LOCALAPPDATA is unavailable or relative.'))
        else:
            for channel, relative in (
                ('stable', 'Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json'),
                ('preview', 'Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json'),
                ('unpackaged', 'Microsoft/Windows Terminal/settings.json')):
                target = Path(localapp) / relative
                try:
                    status = 'missing' if not target.is_file() else ('reference-found' if target.resolve() ==
                             (repo / 'windows-terminal/settings.json').resolve() else 'mismatch')
                    checks.append(item('windows-terminal.' + channel, status,
                                       'Per-channel file target comparison; channel selection and live terminal are unverified.'))
                except (OSError, RuntimeError):
                    checks.append(item('windows-terminal.' + channel, 'unknown', 'Target cannot be resolved.'))
        checks.append(item('autohotkey.startup', 'unknown', 'Shortcut arguments/running process not inspected in this version.'))
        checks.append(mux_check(repo))
    else:
        checks.append(item('shell.profiles', 'unknown', 'Unix shell startup files are not interpreted; Windows host paths are not inspected.'))
    summary = {status: sum(check['status'] == status for check in checks) for status in LABELS}
    return {'schemaVersion': 1, 'environment': detected, 'sourceCheckout': str(repo),
            'readOnly': True, 'summary': summary, 'checks': checks,
            'limitations': ['No install, state writes, source execution, version commands, or explicit network requests.',
                            'References and records are not runtime verification. Optional-feature selection is not inferred.',
                            'File/PATH lookups can access network shares if existing paths point there.',
                            'Native Linux remains unverified on hardware; first release has partial component coverage.']}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--json', action='store_true', help='Machine-readable inventory (not persistent device state).')
    parser.add_argument('--repo', type=Path, default=ROOT, help='Inspect another source checkout without changing links.')
    args = parser.parse_args(argv)
    try:
        report = collect(args.repo)
    except (env.EnvironmentError, OSError, RuntimeError, ValueError):
        if args.json:
            print(json.dumps({'readOnly': True, 'error': 'Unable to inspect this environment safely.'}))
        else:
            print('Unable to inspect this environment safely.', file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(report, indent=2, ensure_ascii=True))
    else:
        print('Environment: ' + report['environment'] + ' | READ ONLY | runtime not verified')
        print('Source: ' + report['sourceCheckout'])
        print(' | '.join(LABELS[status] + ': ' + str(count) for status, count in report['summary'].items() if count))
        for check in report['checks']:
            print(f"[{LABELS[check['status']]}] {check['component']}: {check['detail']}")
        print('Inspection finished; missing/unknown entries are not installation instructions. Use --json for structured output.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
