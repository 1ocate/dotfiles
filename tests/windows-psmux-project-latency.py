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
import uuid

ROOT = Path(__file__).resolve().parents[1]
METRICS=[]


def until(predicate, description, timeout=12):
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
    source_session="probe-"+uuid.uuid4().hex[:12]
    metrics={}
    METRICS.append(metrics)
    if os.name != 'nt':
        raise SystemExit('Requires approved native Windows psmux, pwsh and fzf; no installation.')
    binary = Path(os.environ['LOCALAPPDATA']) / 'Programs/psmux/3.3.8/psmux.exe'
    pwsh = shutil.which('pwsh')
    assert binary.is_file() and pwsh and shutil.which('fzf')
    lock_before = (ROOT / 'nvim/lazy-lock.json').read_bytes()
    roots_file = ROOT / '.local/project-paths.txt'
    roots_before = roots_file.read_bytes() if roots_file.exists() else None
    picker_path = None
    with tempfile.TemporaryDirectory(prefix='dotfiles-project-flow-', ignore_cleanup_errors=True) as temporary:
        temp = Path(temporary).resolve()
        env = os.environ.copy()
        for key in list(env):
            if key.startswith('PSMUX_') or key in ('TMUX', 'TMUX_PANE') or key.startswith('FZF_'):
                env.pop(key)
        runtime = temp / 'registry'
        runtime.mkdir()
        input_dir = temp / 'input'
        input_dir.mkdir()
        project = temp / '한글 project'
        project.mkdir()
        picker_path = project
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
        expected_sessions = {source_session, session_name(project)}

        def run(*args, inside=None, check=True):
            caller = env.copy()
            if inside:
                caller['TMUX'] = 'test,' + (runtime / (inside + '.port')).read_text().strip() + ',0'
            started_cli=time.perf_counter()
            result = subprocess.run([str(binary), *args], env=caller,
                                    capture_output=True, text=True, encoding='utf-8', timeout=20)
            metrics.setdefault('cli_ms',[]).append((time.perf_counter()-started_cli)*1000)
            if check and result.returncode:
                raise AssertionError('Private CLI exit ' + str(result.returncode))
            return result.stdout.strip()

        def attached(session):
            return bool(run('-t', session, 'list-clients', check=False))

        def send(data):
            with (input_dir / 'conpty_ctrl.txt').open('a', encoding='ascii') as file:
                file.write('HEX ' + data.hex() + '\n')

        try:
            entry=temp/'entry.ps1'
            entry.write_text(". '"+str(ROOT/'powershell/psmux.ps1').replace("'","''")+"'\nInvoke-DotfilesMux -Session '"+source_session+"'\n",encoding='utf-8-sig')
            command = subprocess.list2cmdline([pwsh, '-NoLogo', '-NoProfile', '-File', str(entry)])
            startup = subprocess.STARTUPINFO()
            startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startup.wShowWindow = 0
            host = subprocess.Popen([str(host_exe), command], env=env,
                                    startupinfo=startup, creationflags=subprocess.CREATE_NEW_CONSOLE)
            until(lambda: attached(source_session), 'Source launcher failed to attach main')
            assert 'PSMUX_CONFIG_FILE=' + str(ROOT / 'tmux/psmux.conf') in run('-t', source_session, 'show-environment')
            keys = run('-t', source_session, 'list-keys')
            assert ' F new-window ' in keys and ' D new-window ' in keys, keys
            print('Direct path registered:',Path(pwsh).as_posix().lower() in keys.lower(),flush=True)
            print('PASS: source launcher creates and attaches unique fixture with source config and original F/D', flush=True)
            source_ready=temp/'source-ready.txt'
            send(("[IO.File]::WriteAllText('"+str(source_ready).replace("'","''")+"','ready')\r").encode('utf-8'))
            until(lambda: source_ready.exists(), 'Source shell not ready')
            # Prefix is checked in source options, but use Ctrl+B in our private fixture:
            # ConPTY character injection cannot establish physical Ctrl+Space modifier state.
            assert run('-t', source_session, 'show-options', '-g', 'prefix') == 'prefix C-Space'
            run('-t', source_session, 'set-option', '-g', 'prefix', 'C-b')
            time.sleep(1)
            measurements=[]
            for variant in ('source-config',):
                for sample in range(1):
                    started=time.perf_counter()
                    offset=(input_dir/'conpty_out.bin').stat().st_size
                    send(b'\x02F')
                    until(lambda: b'Project>' in (input_dir/'conpty_out.bin').read_bytes()[offset:],'F did not launch fzf')
                    elapsed=(time.perf_counter()-started)*1000
                    measurements.append({'variant':variant,'sample':sample,'f_to_fzf_ms':elapsed})
                    print(json.dumps(measurements[-1]),flush=True)
                    send(b'\x03')
                    ready=temp/('cancel-'+str(sample)+'.txt')
                    time.sleep(0.5)
                    send(("[IO.File]::WriteAllText('"+str(ready).replace("'","''")+"','ready')\r").encode('utf-8'))
                    until(lambda: ready.exists(),'Cancellation shell not ready')
                    assert attached(source_session)
            metrics['measurements']=measurements
            send(b'\x02r')
            until(lambda: run('-t',source_session,'show-options','-g','prefix')=='prefix C-Space','Reload prefix failed')
            def restored_bindings():
                keys = run('-t', source_session, 'list-keys')
                executable = Path(pwsh).as_posix().lower()
                return all(any(' ' + key + ' new-window ' in line and executable in line.lower()
                               and command in line for line in keys.splitlines())
                           for key, command in (('F', '-Command t'), ('D', '-Command Invoke-DotfilesConfigProject')))
            until(restored_bindings, 'Reload lost direct F/D executable paths')
            run('-t',source_session,'set-option','-g','prefix','C-b')
            time.sleep(1)
            offset=(input_dir/'conpty_out.bin').stat().st_size
            send(b'\x02F')
            until(lambda: b'Project>' in (input_dir/'conpty_out.bin').read_bytes()[offset:],'F failed after reload')
            send(b'\x03')
            print('PASS: reload restores prefix and retains direct F/D; F executes after reload',flush=True)
        except Exception as error:
            metrics['failure']=str(error) if isinstance(error,AssertionError) else type(error).__name__
            print('FAIL: '+metrics['failure'],flush=True)
            print('Pane commands:',run('-t',source_session,'list-panes','-a','-F','#{pane_current_command}',check=False),flush=True)
            output=(input_dir/'conpty_out.bin').read_bytes().decode('utf-8',errors='replace')
            print('Known output errors:',json.dumps({k:k.lower() in output.lower() for k in ['file not found','not recognized','Get-Content','ParameterBinding','error','exception']}),flush=True)
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
    assert (ROOT / 'nvim/lazy-lock.json').read_bytes() == lock_before
    assert (roots_file.read_bytes() if roots_file.exists() else None) == roots_before
    print('PASS: only private sessions cleaned; user lockfile and project roots preserved', flush=True)


if __name__ == '__main__':
    for iteration in range(1):
        main()
    (ROOT/'.local/mux-project-latency-results.json').write_text(json.dumps(METRICS,indent=2),encoding='utf-8')
