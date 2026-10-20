"""Real source launcher, mux/t and project-key workflow in a private psmux registry."""
import hashlib
import json
import os
import sys
sys.stdout.reconfigure(encoding='utf-8')
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def until(predicate, description, timeout=35):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(0.15)
    raise AssertionError(description)


def session_name(path):
    import re
    suffix = hashlib.sha256(str(path).rstrip('\\').lower().encode()).hexdigest()[:12]
    name = re.sub('_+', '_', re.sub('[^a-zA-Z0-9_-]', '_', path.name or path.drive)).strip('_') or 'project'
    return name + '-' + suffix


def main():
    if os.name != 'nt':
        raise SystemExit('Requires approved native Windows psmux, pwsh and fzf; no installation.')
    binary = Path(os.environ['LOCALAPPDATA']) / 'Programs/psmux/3.3.8/psmux.exe'
    pwsh = shutil.which('pwsh')
    assert binary.is_file() and pwsh and shutil.which('fzf')
    lock_before = (ROOT / 'nvim/lazy-lock.json').read_bytes()
    roots_file = ROOT / '.local/project-paths.txt'
    roots_before = roots_file.read_bytes() if roots_file.exists() else None
    roots = [ROOT]
    if roots_file.exists():
        roots = [Path(line).expanduser() for line in roots_file.read_text(encoding='utf-8-sig').splitlines()
                 if line.strip() and not line.startswith('#')]
    picker_path = next((path.resolve() for path in roots if path.is_dir()), None)
    assert picker_path, 'No valid configured project root for F picker'
    with tempfile.TemporaryDirectory(prefix='dotfiles-project-flow-', ignore_cleanup_errors=True) as temporary:
        temp = Path(temporary).resolve()
        env = os.environ.copy()
        for key in list(env):
            if key.startswith('PSMUX_') or key in ('TMUX', 'TMUX_PANE') or key.startswith('FZF_'):
                env.pop(key)
        runtime = temp / 'registry'
        input_dir = temp / 'input'
        input_dir.mkdir()
        project = temp / '한글 project'
        project.mkdir()
        env.update(PSMUX_DATA_DIR=str(runtime), PSMUX_NO_WARM='1',
                   DOTFILES_PROBE_DIR=str(input_dir), DOTFILES_PROBE_PROJECT=str(project),
                   DOTFILES_PROBE_RESULT=str(temp / 'direct.json'),
                   FZF_DEFAULT_OPTS="--query='^" + str(picker_path).replace("'", "'\\''") + "'")
        env['PATH'] = str(binary.parent) + ';' + env['PATH']
        host_exe = temp / 'host.exe'
        compiler = Path(os.environ['WINDIR']) / 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
        subprocess.run([str(compiler), '/nologo', '/out:' + str(host_exe),
                        str(ROOT / 'tests/psmux-input-host.cs')], check=True, capture_output=True, timeout=30)
        host = None
        expected_sessions = {'main', session_name(project), session_name(picker_path), session_name(ROOT), 'foreign'}

        def run(*args, inside=None, check=True):
            caller = env.copy()
            if inside:
                caller['TMUX'] = 'test,' + (runtime / (inside + '.port')).read_text().strip() + ',0'
            result = subprocess.run([str(binary), *args], env=caller,
                                    capture_output=True, text=True, encoding='utf-8', timeout=20)
            if check and result.returncode:
                raise AssertionError((args, result.stderr))
            return result.stdout.strip()

        def attached(session):
            return bool(run('-t', session, 'list-clients', check=False))

        def send(data):
            with (input_dir / 'conpty_ctrl.txt').open('a', encoding='ascii') as file:
                file.write('HEX ' + data.hex() + '\n')

        try:
            command = subprocess.list2cmdline([pwsh, '-NoLogo', '-NoProfile', '-File',
                                              str(ROOT / 'scripts/start-psmux.ps1')])
            startup = subprocess.STARTUPINFO()
            startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startup.wShowWindow = 0
            host = subprocess.Popen([str(host_exe), command], env=env,
                                    startupinfo=startup, creationflags=subprocess.CREATE_NEW_CONSOLE)
            until(lambda: attached('main'), 'Source launcher failed to attach main')
            assert 'PSMUX_CONFIG_FILE=' + str(ROOT / 'tmux/psmux.conf') in run('-t', 'main', 'show-environment')
            keys = run('-t', 'main', 'list-keys')
            assert ' F new-window ' in keys and ' D new-window ' in keys, keys
            print('PASS: source launcher creates and attaches default main with source config and F/D', flush=True)
            direct = temp / 'direct.ps1'
            direct.write_text("$ErrorActionPreference='Stop'\n. '" + str(ROOT / 'powershell/psmux.ps1').replace("'", "''") +
                "'\ntry { t -Path $env:DOTFILES_PROBE_PROJECT; @{ok=$true} | ConvertTo-Json | Set-Content $env:DOTFILES_PROBE_RESULT } catch { @{ok=$false;error=$_.Exception.Message} | ConvertTo-Json | Set-Content $env:DOTFILES_PROBE_RESULT }\n", encoding='utf-8-sig')
            # Execute t through the actual attached shell, including its profile/aliases.
            send(("& '" + str(direct).replace("'", "''") + "'\r").encode('utf-8'))
            target = session_name(project)
            until(lambda: attached(target), 'Actual t command failed to create and switch project')
            result = until(lambda: json.loads((temp / 'direct.json').read_text(encoding='utf-8-sig'))
                           if (temp / 'direct.json').exists() and (temp / 'direct.json').stat().st_size else None,
                           'Direct t did not finish')
            assert result['ok'], result
            assert os.path.normcase(run('-t', target, 'display-message', '-p', '#{pane_current_path}')) == os.path.normcase(str(project))
            print('PASS: real t creates Unicode/space project and actually moves client', flush=True)
            run('switch-client', '-t', '=main', inside=target)
            until(lambda: attached('main'), 'Client failed to return to main')
            # Prefix is checked in source options, but use Ctrl+B in our private fixture:
            # ConPTY character injection cannot establish physical Ctrl+Space modifier state.
            assert run('-t', 'main', 'show-options', '-g', 'prefix') == 'prefix C-Space'
            run('-t', 'main', 'set-option', '-g', 'prefix', 'C-b')
            time.sleep(1)  # Wait for the private prefix to reach the client.
            picker_offset = (input_dir / 'conpty_out.bin').stat().st_size
            send(b'\x02F')
            until(lambda: b'Project>' in (input_dir / 'conpty_out.bin').read_bytes()[picker_offset:],
                  'F did not launch real fzf')
            send(b'\r')
            picker_session = session_name(picker_path)
            until(lambda: attached(picker_session), 'F picker selection did not switch to selected project')
            print('PASS: actual prefix+F dispatcher, real fzf selection and session switch', flush=True)
            run('switch-client', '-t', '=main', inside=picker_session)
            until(lambda: attached('main'), 'Failed to return after F')
            picker_offset = (input_dir / 'conpty_out.bin').stat().st_size
            send(b'\x02F')
            until(lambda: b'Project>' in (input_dir / 'conpty_out.bin').read_bytes()[picker_offset:],
                  'Second F did not start picker')
            cancelled_pane = run('-t', 'main', 'display-message', '-p', '#{pane_id}')
            send(b'\x03')
            cancelled_ready = temp / 'cancelled-ready.txt'
            time.sleep(0.5)
            send(("[IO.File]::WriteAllText('" + str(cancelled_ready).replace("'", "''") + "','ready')\r").encode('utf-8'))
            until(lambda: cancelled_ready.exists(), 'Cancelled picker did not restore its shell')
            assert attached('main'), 'Cancellation moved the client'
            until(lambda: cancelled_pane + ' pwsh' in run('-t', 'main', 'list-panes', '-a', '-F', '#{pane_id} #{pane_current_command}'),
                  'Cancelled picker did not keep its PowerShell pane')
            print('PASS: real picker cancellation keeps session and shell', flush=True)
            send(b'\x02D')
            until(lambda: attached(session_name(ROOT)), 'D did not select source checkout')
            print('PASS: actual prefix+D selects source checkout', flush=True)
            checkout_session = session_name(ROOT)
            run('-t', checkout_session, 'set-option', '-g', 'prefix', 'C-b')
            send(b'\x02r')
            until(lambda: run('-t', checkout_session, 'show-options', '-g', 'prefix') == 'prefix C-Space',
                  'Reload key did not read the source config')
            assert 'Invoke-DotfilesConfigProject' in run('-t', checkout_session, 'list-keys')
            print('PASS: actual reload dispatcher reads source and restores configured prefix', flush=True)
            run('-f', str(ROOT / 'tmux/psmux.conf'), 'new-session', '-d', '-s', 'foreign',
                '--', pwsh, '-NoLogo', '-NoProfile', '-Command', 'Start-Sleep 120')
            # Simulate another config on only our foreign test server; wrapper must refuse it.
            run('-t', 'foreign', 'set-environment', 'PSMUX_CONFIG_FILE', str(temp / 'foreign.conf'))
            probe = subprocess.run([pwsh, '-NoLogo', '-NoProfile', '-Command',
                                   ". '" + str(ROOT / 'powershell/psmux.ps1') +
                                   "'; try { Invoke-DotfilesMux -Session foreign; exit 9 } catch { if($_.Exception.Message -like '*another configuration*'){exit 0}; throw }"],
                                   env=env, capture_output=True, text=True, timeout=25)
            assert probe.returncode == 0, (probe.stdout, probe.stderr)
            run('has-session', '-t', '=foreign')
            print('PASS: another config session is refused and preserved', flush=True)
        except Exception:
            print('DEBUG private sessions:', run('list-sessions', check=False), flush=True)
            print('DEBUG private panes:', run('-t', 'main', 'list-panes', '-a', '-F', '#{pane_current_command} #{pane_current_path}', check=False), flush=True)
            if (temp / 'direct.json').exists():
                print('DEBUG direct result:', (temp / 'direct.json').read_text(encoding='utf-8-sig'), flush=True)
            print('DEBUG private main:', run('-t', 'main', 'capture-pane', '-p', check=False), flush=True)
            raise
        finally:
            errors = []
            try:
                for name in expected_sessions:
                    try:
                        run('kill-session', '-t', '=' + name, check=False)
                    except (OSError, subprocess.SubprocessError) as error:
                        errors.append(str(error))
            finally:
                if host:
                    try:
                        (input_dir / 'conpty_ctrl.txt').write_text('QUIT\n', encoding='ascii')
                        host.wait(timeout=10)
                    except (OSError, subprocess.TimeoutExpired):
                        host.kill()
                        host.wait(timeout=5)
            until(lambda: not run('list-sessions'), 'Private sessions did not terminate')
            assert not errors, errors
    assert (ROOT / 'nvim/lazy-lock.json').read_bytes() == lock_before
    assert (roots_file.read_bytes() if roots_file.exists() else None) == roots_before
    print('PASS: only private sessions cleaned; user lockfile and project roots preserved', flush=True)


if __name__ == '__main__':
    main()
