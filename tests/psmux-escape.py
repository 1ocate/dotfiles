"""Isolated attached-client Escape transport probe (no actual SSH or remote Vim).

Reader modes model SSH-style VT byte input and Console.ReadKey respectively.
Every case uses a fresh pane and a real attached client, with a horizontal split.
"""
import argparse
import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]

def until(predicate, message, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(.1)
    raise AssertionError(message)

def alive(pid):
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    handle = kernel.OpenProcess(0x100000, False, pid)
    if not handle:
        return False
    try:
        return kernel.WaitForSingleObject(handle, 0) == 258
    finally:
        kernel.CloseHandle(handle)

def main():
    if os.name != 'nt':
        raise SystemExit('Native Windows required; no installation performed.')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wezterm', action='store_true', help='Force the psmux WezTerm VT input branch; no real GUI is started.')
    parser.add_argument('--case', action='append', help='Select named cases (repeatable).')
    parser.add_argument('--mode', action='append', choices=('raw', 'keys', 'events'))
    parser.add_argument('--require-all', action='store_true', help='Require Esc in synthetic modifier stress cases too (fails on psmux 3.3.8 VT input).')
    parser.add_argument('--encoded-escape', action='store_true', help='Encode client Esc as Win32 VkEscape with UnicodeChar zero.')
    parser.add_argument('--direct', action='store_true', help='Bypass psmux; exercise ConPTY host directly against the reader.')
    parser.add_argument('--encoding', choices=('win32', 'csi-u', 'modify-other-keys'), default='win32')
    parser.add_argument('--trace', action='store_true', help='Print only isolated psmux KEY/emit/pending trace lines.')
    args = parser.parse_args()
    binary = Path(os.environ['LOCALAPPDATA']) / 'Programs/psmux/3.3.8/psmux.exe'
    csc = Path(os.environ['WINDIR']) / 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    if (not args.direct and not binary.is_file()) or not csc.is_file():
        raise SystemExit('Existing psmux 3.3.8 and .NET Framework compiler required.')
    lock = ROOT / 'nvim/lazy-lock.json'
    before = lock.read_bytes()
    namespace = 'dotfiles-escape-' + uuid.uuid4().hex[:8]
    results = []
    with tempfile.TemporaryDirectory(prefix=namespace, ignore_cleanup_errors=True) as directory:
        temp = Path(directory)
        env = os.environ.copy()
        for name in list(env):
            if name in ('TMUX', 'TMUX_PANE') or name.startswith('PSMUX_'):
                env.pop(name)
        env.update(PSMUX_DATA_DIR=str(temp / 'runtime'), PSMUX_NO_WARM='1', DOTFILES_PROBE_DIR=str(temp))
        for key in ('WEZTERM_PANE', 'WEZTERM_EXECUTABLE', 'TERM_PROGRAM'):
            env.pop(key, None)
        if args.wezterm:
            env.update(WEZTERM_PANE='0', WEZTERM_EXECUTABLE=shutil.which('wezterm.exe') or 'wezterm.exe', TERM_PROGRAM='WezTerm')
        if args.trace:
            env['PSMUX_SSH_DEBUG'] = '1'
        host, reader = temp / 'host.exe', temp / 'reader.exe'
        for output, source in ((host, 'psmux-input-host.cs'), (reader, 'psmux-key-reader.cs')):
            subprocess.run([str(csc), '/nologo', '/out:' + str(output), str(ROOT / 'tests' / source)], check=True, capture_output=True, timeout=30)
        def run(*args, check=True):
            result = subprocess.run([str(binary), '-L', namespace, *args], env=env, capture_output=True, text=True, timeout=30)
            if check and result.returncode:
                raise AssertionError(str(args) + ': ' + result.stderr)
            return result.stdout.strip()
        def control_command(command):
            # The host briefly opens this file without write sharing when polling.
            deadline = time.monotonic() + 3
            while True:
                try:
                    with (temp / 'conpty_ctrl.txt').open('a', encoding='ascii') as control:
                        control.write(command + '\n')
                    return
                except PermissionError:
                    if time.monotonic() >= deadline:
                        raise
                    time.sleep(.01)
        def feed(data):
            control_command('HEX ' + data.hex())
        process = None
        try:
            wait = temp / 'wait.ps1'
            wait.write_text('Start-Sleep -Seconds 180\n')
            startup = subprocess.STARTUPINFO()
            startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startup.wShowWindow = 0
            if not args.direct:
                run('-f', str(ROOT / 'tmux/psmux.conf'), 'new-session', '-d', '-s', 'probe', '--', 'pwsh', '-NoProfile', '-File', str(wait))
                run('split-window', '-h', '-d', '--', 'pwsh', '-NoProfile', '-File', str(wait))
                command = subprocess.list2cmdline([str(binary), '-L', namespace, 'attach-session', '-t', '=probe'])
                process = subprocess.Popen([str(host), command], env=env, startupinfo=startup, creationflags=subprocess.CREATE_NEW_CONSOLE)
                until(lambda: run('list-clients'), 'Client failed to attach')
            # Encoded events include both plausible Esc scan codes. CLI byte injection
            # exercises the binding action; client injection also exercises decoding.
            cases = [('client-Escape', None, b'\x1b'),
                     ('client-double-Escape', None, b'\x1b\x1b'),
                     ('client-Escape-modifier', None, b'\x1b\x1b[16;42;0;1;0;1_'),
                     ('client-Escape-modifier-delayed', None, (b'\x1b', b'\x1b[16;42;0;1;0;1_')),
                     ('client-Escape-unicode0', None, b'\x1b\x1b[27;1;0;1;0;1_'),
                     ('send-keys-Escape', ('send-keys', 'Escape'), None),
                     ('send-key-esc', ('send-key', 'esc'), None),
                     ('send-keys-C-[', ('send-keys', 'C-['), None),
                     ('hex-win32-scan0', ('send-keys', '-H', '1b','5b','32','37','3b','30','3b','32','37','3b','31','3b','30','3b','31','5f'), None),
                     ('literal-win32-scan0', ('send-keys', '-l', '\x1b[27;0;27;1;0;1_'), None),
                     ('literal-win32-scan1', ('send-keys', '-l', '\x1b[27;1;27;1;0;1_'), None)]
            for mode in args.mode or ('raw', 'keys', 'events'):
                for index, (name, cli, data) in enumerate(cases):
                    if args.case and name not in args.case:
                        continue
                    if args.direct and cli is not None:
                        continue
                    output = temp / (mode + str(index) + '.txt')
                    if args.direct:
                        (temp / 'conpty_ctrl.txt').write_text('')
                        command = subprocess.list2cmdline([str(reader), mode, str(output)])
                        process = subprocess.Popen([str(host), command], env=env, startupinfo=startup, creationflags=subprocess.CREATE_NEW_CONSOLE)
                    else:
                        pane = run('split-window', '-h', '-P', '-F', '#{pane_id}', '--', str(reader), mode, str(output))
                    until(lambda: Path(str(output)+'.ready').exists(), 'Reader did not initialize')
                    time.sleep(.3)
                    if data is not None:
                        if args.encoded_escape:
                            encoded = {'win32': b'\x1b[27;1;0;1;0;1_', 'csi-u': b'\x1b[27;1u', 'modify-other-keys': b'\x1b[27;1;27~'}[args.encoding]
                            if isinstance(data, tuple):
                                data = (encoded, data[1])
                            elif data.startswith(b'\x1b'):
                                data = encoded + data[1:]
                        if isinstance(data, tuple):
                            feed(data[0])
                            time.sleep(.005)
                            feed(data[1])
                        else:
                            feed(data)
                    else:
                        run(*cli)
                    time.sleep(1.5) # A lone Esc must arrive before any following key.
                    first = output.read_text() if output.exists() else ''
                    if 'modifier' in name:
                        feed(b'\x1b[16;42;0;0;0;1_') # Release Shift before next input/fixture.
                        time.sleep(.1)
                    feed(b'x')
                    time.sleep(.5)
                    after = output.read_text() if output.exists() else ''
                    if mode == 'raw':
                        tokens = first.replace('\n', '-').strip('-').split('-') if first else []
                        escape_count = tokens.count('1B')
                        if any(token != '1B' for token in tokens):
                            escape_count = 0 # Literal unsupported CSI must not count as Esc.
                    elif mode == 'keys':
                        escape_count = first.count('key=Escape')
                    else:
                        escape_count = sum('vk=27 ' in line and 'down=1 ' in line for line in first.splitlines())
                    escaped = escape_count > 0
                    result = dict(encoding=args.encoding, escape_count=escape_count, direct=args.direct, encoded_escape=args.encoded_escape, escape_received=escaped, wezterm=args.wezterm, mode=mode, case=name, before_x=first, after_x=after)
                    results.append(result)
                    print(json.dumps(result), flush=True)
                    if args.direct:
                        control_command('QUIT')
                        process.wait(timeout=10)
                        process = None
                    else:
                        run('kill-pane', '-t', pane)
        finally:
            pids = []
            for path in (temp / 'runtime').rglob('*.pid'):
                try:
                    pids.append(int(path.read_text().strip()))
                except (ValueError, FileNotFoundError):
                    pass
            try:
                if not args.direct:
                    run('kill-server', check=False)
                until(lambda: not any(alive(pid) for pid in pids), 'Isolated server did not terminate', timeout=10)
            finally:
                try:
                    if process is not None:
                        try:
                            control_command('QUIT')
                            process.wait(timeout=10)
                        finally:
                            if process.poll() is None:
                                process.terminate()
                                process.wait(timeout=5)
                finally:
                    try:
                        if args.trace:
                            for trace in (temp / 'runtime').rglob('ssh_input.log'):
                                for line in trace.read_text(encoding='utf-8', errors='replace').splitlines():
                                    if 'KEY vk=' in line or 'emit(' in line or 'pending' in line.lower():
                                        print('TRACE:', line, flush=True)
                    finally:
                        assert before == lock.read_bytes(), 'User lockfile changed'
            print('PASS: isolated servers terminated and user lockfile bytes preserved', flush=True)
    # Assert real transport for ordinary keys. Synthetic modifier cases diagnose
    # a separate VT parser loss; --require-all makes that desired behavior a test.
    assert results, 'No selected cases were executed'
    for result in results:
        stress = 'modifier' in result['case']
        if not stress or args.require_all:
            assert result['escape_received'], result
            expected = 2 if result['case'] == 'client-double-Escape' else 1
            assert result['escape_count'] == expected, result
        lines = result['after_x'].splitlines()
        if result['mode'] == 'raw':
            received_x = any('78' in line.split('-') for line in lines)
        elif result['mode'] == 'keys':
            received_x = any(line.startswith('78 key=X ') for line in lines)
        else:
            received_x = any(line.startswith('char=78 ') and 'down=1 ' in line for line in lines)
        assert received_x, result
    print('PASS: ordinary Escape delivery assertions; synthetic stress cases reported separately')
    # These are local transport assertions, not a real SSH/Vim functional check.
    return results

if __name__ == '__main__':
    main()
