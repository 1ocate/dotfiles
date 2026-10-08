"""Compare pinned Windows psmux/tmux session switching with real ConPTY clients.

All servers use fresh PSMUX_DATA_DIRs; no user session or configuration is changed.
The named-namespace failure is an expected observation of pinned 3.3.8, not a fix.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]


def wait_for(predicate, description, timeout=15):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(0.1)
    raise AssertionError(description)


def main():
    if os.name != 'nt':
        raise SystemExit('Native Windows is required; no tools are installed by this test.')
    directory = Path(os.environ['LOCALAPPDATA']) / 'Programs/psmux/3.3.8'
    binaries = {name: directory / (name + '.exe') for name in ('psmux', 'tmux')}
    pwsh = shutil.which('pwsh')
    csc = Path(os.environ['WINDIR']) / 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    if not pwsh or not csc.is_file() or not all(p.is_file() for p in binaries.values()):
        raise SystemExit('Installed PowerShell 7, psmux/tmux 3.3.8 and C# compiler are required.')
    lock_before = (ROOT / 'nvim/lazy-lock.json').read_bytes()
    results = []
    with tempfile.TemporaryDirectory(prefix='dotfiles-session-check-', ignore_cleanup_errors=True) as temporary:
        temp = Path(temporary).resolve()
        host_exe = temp / 'input-host.exe'
        subprocess.run([str(csc), '/nologo', '/out:' + str(host_exe),
                        str(ROOT / 'tests/psmux-input-host.cs')], check=True,
                       capture_output=True, timeout=30)
        config = temp / 'probe.conf'
        config.write_text('set -g default-shell pwsh\nset -g warm off\n', encoding='utf-8')
        # A minimal explicit config excludes implicit home config and profile writes.
        wait_script = temp / 'wait.ps1'
        wait_script.write_text('Start-Sleep -Seconds 180\n', encoding='utf-8-sig')
        version_env = os.environ.copy()
        version_env['PSMUX_DATA_DIR'] = str(temp / 'version-registry')
        for name, binary in binaries.items():
            version = subprocess.run([str(binary), '-V'], env=version_env, capture_output=True,
                                     text=True, timeout=15)
            assert version.returncode == 0 and '3.3.8' in version.stdout, version
            print(name, version.stdout.strip().replace('\n', '; '), flush=True)
            print('SHA256', hashlib.sha256(binary.read_bytes()).hexdigest(), flush=True)
            for named in (False, True):
                case = temp / (name + ('-named' if named else '-default'))
                case.mkdir()
                runtime = case / 'runtime'
                input_dir = case / 'input'
                input_dir.mkdir()
                work = case / '한글 project'
                work.mkdir()
                ns = 'verify-' + uuid.uuid4().hex[:8] if named else None
                prefix = ['-L', ns] if ns else []
                env = os.environ.copy()
                env.pop('TMUX', None)
                env.pop('TMUX_PANE', None)
                for key in list(env):
                    if key.startswith('PSMUX_'):
                        env.pop(key)
                env.update(PSMUX_DATA_DIR=str(runtime), PSMUX_NO_WARM='1',
                           DOTFILES_PROBE_DIR=str(input_dir))
                env['PATH'] = str(directory) + ';' + env['PATH']
                other = binaries['tmux' if name == 'psmux' else 'psmux']
                host = None
                created = []

                def run(*args, exe=binary, inside=None, check=True):
                    run_env = env.copy()
                    if inside:
                        base = (ns + '__' if ns else '') + inside
                        port = (runtime / (base + '.port')).read_text().strip()
                        run_env['TMUX'] = 'test,' + port + ',0'
                    result = subprocess.run([str(exe), *prefix, *args], env=run_env,
                                            capture_output=True, text=True,
                                            encoding='utf-8', timeout=20)
                    if check and result.returncode:
                        raise AssertionError(f'{name} {ns} {args}: {result.stderr}')
                    return result

                def attached(session):
                    return bool(run('-t', session, 'list-clients').stdout.strip())

                try:
                    for session in ('source', 'project'):
                        run('-f', str(config), 'new-session', '-d', '-s', session,
                            '-c', str(work), '--', pwsh, '-NoLogo', '-NoProfile',
                            '-File', str(wait_script))
                        created.append(session)
                        run('has-session', '-t', '=' + session, exe=other)
                    listing = run('list-sessions', '-F', '#{session_name}').stdout.splitlines()
                    assert sorted(listing) == ['project', 'source'], listing
                    path = run('-t', 'project', 'display-message', '-p', '#{pane_current_path}').stdout.strip()
                    assert os.path.normcase(os.path.normpath(path)) == os.path.normcase(str(work)), path
                    command = subprocess.list2cmdline([str(binary), *prefix, 'attach-session', '-t', '=source'])
                    startup = subprocess.STARTUPINFO()
                    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                    startup.wShowWindow = 0
                    host = subprocess.Popen([str(host_exe), command], env=env,
                                            startupinfo=startup,
                                            creationflags=subprocess.CREATE_NEW_CONSOLE)
                    wait_for(lambda: attached('source'), 'Client failed to attach to source')
                    switch = run('switch-client', '-t', '=project', inside='source', check=False)
                    observation = dict(command=name, namespace='named' if named else 'default',
                                       switch_exit=switch.returncode, stderr=switch.stderr.strip())
                    if named:
                        assert switch.returncode != 0 and "can't find session" in switch.stderr, observation
                        assert attached('source') and not attached('project'), 'Failed switch moved client'
                        # A command rename and full namespaced target do not bypass the filter.
                        for destination in ('project', ns + '__project', '=' + ns + '__project'):
                            failure = run('switch-client', '-t', destination, exe=other,
                                          inside='source', check=False)
                            assert failure.returncode != 0, (destination, failure.stdout)
                        observation['round_trips'] = 0
                    else:
                        assert switch.returncode == 0, observation
                        wait_for(lambda: attached('project') and not attached('source'),
                                 'Successful CLI did not actually move client')
                        for _ in range(3):
                            run('switch-client', '-t', '=source', exe=other, inside='project')
                            wait_for(lambda: attached('source') and not attached('project'), 'Return switch failed')
                            run('switch-client', '-t', '=project', inside='source')
                            wait_for(lambda: attached('project') and not attached('source'), 'Project switch failed')
                        observation['round_trips'] = 3
                        missing = run('switch-client', '-t', '=missing', inside='project', check=False)
                        assert missing.returncode != 0 and "can't find session" in missing.stderr, missing.stderr
                        assert attached('project'), 'Missing target detached the client'
                    for session in created:
                        run('has-session', '-t', '=' + session, exe=other)
                    observation.update(shared_sessions=True, unicode_cwd=True, sessions_preserved=True)
                    results.append(observation)
                    print(json.dumps(observation, ensure_ascii=False), flush=True)
                finally:
                    # Never a bare kill-server: only names this test created, in its private registry.
                    cleanup_errors = []
                    try:
                        for session in created:
                            try:
                                run('kill-session', '-t', '=' + session, check=False)
                            except (subprocess.SubprocessError, OSError) as error:
                                cleanup_errors.append(error)
                    finally:
                        # Session-command failures must not skip our own helper cleanup.
                        if host:
                            try:
                                (input_dir / 'conpty_ctrl.txt').write_text('QUIT\n', encoding='ascii')
                                host.wait(timeout=8)
                            except (subprocess.TimeoutExpired, OSError):
                                host.kill()  # Only our own helper process.
                                host.wait(timeout=5)

                    def no_sessions():
                        listing = run('list-sessions', check=False)
                        # This pinned version returns exit 0 and empty stdout when empty.
                        # A transport failure is not evidence that the servers stopped.
                        return listing.returncode == 0 and not listing.stdout.strip()

                    wait_for(no_sessions, 'Test sessions remain or registry query failed')
                    assert not cleanup_errors, cleanup_errors
        assert (ROOT / 'nvim/lazy-lock.json').read_bytes() == lock_before, 'User lockfile changed'
    assert len(results) == 4
    print('PASS: real client comparison; default switches work, named failure reproduced; user lockfile preserved', flush=True)


if __name__ == '__main__':
    main()
