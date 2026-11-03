"""Isolated attached-ConPTY Neovim command-line cancellation; no downloads/SSH."""
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

ROOT = Path(__file__).resolve().parents[1]


def full_config_guard():
    # Resolve the same data directory config.lazy will use, including inherited
    # NVIM_APPNAME/XDG_DATA_HOME. cquit exits before -u can reach its bootstrap.
    return (
        "lua local path=vim.fn.stdpath('data')..'/lazy/lazy.nvim'; "
        "local stat=(vim.uv or vim.loop).fs_stat(path); "
        "if not stat or stat.type~='directory' then "
        "vim.api.nvim_err_writeln('Existing lazy.nvim required; bootstrap disabled'); "
        "vim.cmd('cquit 2'); return end; "
        "vim.loader.enable(false); vim.loader.enable=function() end; "
        "vim.opt.rtp:prepend(path); "
        "local lazy=require('lazy'); local original=lazy.setup; "
        "lazy.setup=function(opts) opts.install={missing=false}; "
        "opts.root=vim.fn.stdpath('data')..'/lazy'; "
        "opts.state=vim.env.DOTFILES_SEARCH_CACHE..'/lazy-state.json'; "
        "opts.readme={enabled=false}; "
        "opts.checker={enabled=false}; opts.change_detection={enabled=false}; "
        "opts.pkg={enabled=false}; opts.rocks={enabled=false}; "
        "opts.spec[#opts.spec+1]={'mason.nvim',config=function(_,o) require('mason').setup(o) end}; "
        "opts.spec[#opts.spec+1]={'mason-lspconfig.nvim',opts=function(_,o) "
        "o.ensure_installed={}; o.automatic_installation=false end}; "
        "opts.spec[#opts.spec+1]={'nvim-treesitter',opts=function(_,o) "
        "o.ensure_installed={}; o.auto_install=false end}; return original(opts) end"
    )


def until(predicate, message, timeout=15):
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--encoded-escape', action='store_true')
    parser.add_argument('--latch-control-key', action='store_true',
                        help='Inject CLI Ctrl-A before Escape to probe pane ConPTY input-mode latch')
    parser.add_argument('--config', type=Path,
                        help='Trusted private test configuration; data-dir isolation does not sandbox config commands')
    parser.add_argument('--binary', type=Path,
                        help='Existing candidate psmux executable; never installs or selects it for live sessions')
    parser.add_argument('--full-config', action='store_true',
                        help='Use existing LazyVim/Noice plugins offline; no installation or updates')
    args = parser.parse_args()
    if os.name != 'nt':
        parser.error('Native Windows required; nothing installed')
    binary = (args.binary or Path(os.environ['LOCALAPPDATA']) / 'Programs/psmux/3.4.0/psmux.exe').resolve()
    nvim = shutil.which('nvim')
    csc = Path(os.environ['WINDIR']) / 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    if not binary.is_file() or not nvim or not csc.is_file():
        parser.error('Selected psmux executable, existing Neovim and .NET compiler required')
    config = (args.config or ROOT / 'tmux/psmux.conf').resolve()
    if not config.is_file():
        parser.error('Selected configuration does not exist')
    escape = b'\x1b'
    startup = ['-u', 'NONE']
    if args.full_config:
        startup = ['--cmd', full_config_guard(), '-u', str(ROOT / 'nvim/init.lua')]
    if args.encoded_escape:
        settings = json.loads((ROOT / 'windows-terminal/settings.json').read_text(encoding='utf-8-sig'))
        commands = [a['command'] for a in settings['actions'] if a.get('keys') == 'escape']
        assert len(commands) == 1 and commands[0]['action'] == 'sendInput'
        escape = commands[0]['input'].encode('ascii')
    lock = ROOT / 'nvim/lazy-lock.json'
    before = lock.read_bytes()
    with tempfile.TemporaryDirectory(prefix='dotfiles-search-', ignore_cleanup_errors=True) as directory:
        temp = Path(directory)
        env = os.environ.copy()
        for name in list(env):
            if name in ('TMUX', 'TMUX_PANE', 'WEZTERM_PANE', 'WEZTERM_EXECUTABLE', 'TERM_PROGRAM') or name.startswith('PSMUX_'):
                env.pop(name)
        # Private data namespace, retaining the default socket name required by
        # config.psmux's production ownership guard. Never use the live data dir.
        env.update(PSMUX_DATA_DIR=str(temp / 'runtime'), PSMUX_NO_WARM='1',
                   DOTFILES_PROBE_DIR=str(temp), DOTFILES_ROOT=str(ROOT),
                   NVIM_LOG_FILE=str(temp / 'nvim.log'),
                   XDG_STATE_HOME=str(temp / 'state-home'),
                   XDG_CACHE_HOME=str(temp / 'cache-home'),
                   DOTFILES_SEARCH_CACHE=str(temp / 'cache'),
                   DOTFILES_SEARCH_STATE=str(temp / 'state.json'))
        (temp / 'cache').mkdir()
        if args.full_config:
            # Fail promptly rather than waiting for a fixture state file when
            # inherited stdpath options point at a different/missing install.
            subprocess.run([nvim, '--headless', '-u', 'NONE', '-i', 'NONE',
                            '--cmd', full_config_guard(), '-c', 'qa!'], env=env,
                           check=True, capture_output=True, timeout=30)
        script = temp / 'probe.lua'
        script.write_text("""
vim.g.dotfiles_environment='windows-powershell'
vim.opt.rtp:prepend(vim.env.DOTFILES_ROOT..'/nvim')
require('config.psmux').setup()
vim.opt.swapfile=false
vim.opt.shadafile='NONE'
local prepared=false
vim.defer_fn(function()
  vim.cmd('enew!')
  vim.api.nvim_buf_set_lines(0,0,-1,false,{'alpha probe beta','another probe'})
  prepared=true
end,1500)
local timer=vim.uv.new_timer()
timer:start(50,50,vim.schedule_wrap(function()
  if not prepared then return end
  vim.fn.writefile({vim.json.encode({mode=vim.api.nvim_get_mode().mode,
    cmdline=vim.fn.getcmdline(),cmdtype=vim.fn.getcmdtype(),
    noice=package.loaded['noice']~=nil,
    cursor=vim.api.nvim_win_get_cursor(0),ex_executed=vim.g.dotfiles_search_executed==1,
    search=vim.fn.getreg('/'),line=vim.api.nvim_get_current_line()})},vim.env.DOTFILES_SEARCH_STATE)
end))
""", encoding='utf-8')
        host = temp / 'host.exe'
        subprocess.run([str(csc), '/nologo', '/out:' + str(host), str(ROOT / 'tests/psmux-input-host.cs')],
                       check=True, capture_output=True, timeout=30)

        def run(*command, check=True):
            result = subprocess.run([str(binary), *command], env=env, capture_output=True,
                                    text=True, encoding='utf-8', timeout=30)
            if check and result.returncode:
                raise AssertionError(repr(command) + ': ' + result.stderr)
            return result.stdout.strip()

        def control(command):
            deadline = time.monotonic() + 3
            while True:
                try:
                    with (temp / 'conpty_ctrl.txt').open('a', encoding='ascii') as stream:
                        stream.write(command + '\n')
                    return
                except PermissionError:
                    if time.monotonic() >= deadline:
                        raise
                    time.sleep(.01)

        def feed(data):
            control('HEX ' + data.hex())

        def type_text(data):
            # A burst of printable bytes is deliberately interpreted as paste
            # by psmux; model individual physical keystrokes for command entry.
            for value in data:
                feed(bytes([value]))
                time.sleep(.2)

        def state():
            try:
                return json.loads((temp / 'state.json').read_text(encoding='utf-8'))
            except (FileNotFoundError, json.JSONDecodeError):
                return {}

        def mode(expected):
            return until(lambda: (current := state()) and current['mode'] == expected and current,
                         'Expected mode ' + expected + ', last state: ' + repr(state()))

        process = None
        try:
            run('-f', str(config), 'new-session', '-d', '-s', 'search',
                '-x', '120', '-y', '30', '--', nvim, *startup, '-i', 'NONE', '-S', str(script))
            mode('n')
            startup = subprocess.STARTUPINFO()
            startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startup.wShowWindow = 0
            command = subprocess.list2cmdline([str(binary), 'attach-session', '-t', '=search'])
            process = subprocess.Popen([str(host), command], env=env, startupinfo=startup,
                                       creationflags=subprocess.CREATE_NEW_CONSOLE)
            until(lambda: run('list-clients'), 'Attached client missing')
            # Client registration precedes its input-loop initialization.
            time.sleep(.7)
            print('Foreground:', run('display-message', '-p', '#{pane_current_command}'), 'Noice:', state().get('noice'), flush=True)
            if args.full_config:
                assert state().get('noice'), 'Full-config test must actually load Noice'
            for opener in (b'/', b'?', b':'):
                text = b'let g:dotfiles_search_executed=1' if opener == b':' else b'probe'
                type_text(opener + text)
                try:
                    until(lambda: state().get('mode') == 'c' and state().get('cmdline') == text.decode('ascii'),
                          'Command line did not open: ' + repr(state()))
                except AssertionError:
                    print('Host:', (temp / 'conpty_host.log').read_text(errors='replace'), flush=True)
                    print('Screen:', repr(run('capture-pane', '-p')[-1000:]), flush=True)
                    print('Output:', repr((temp / 'conpty_out.bin').read_bytes()[-800:]), flush=True)
                    raise
                if args.latch_control_key:
                    # Intended as command-line editing input, Ctrl-A traverses
                    # the pane ConPTY path implicated in #588. The pinned path
                    # may instead append a literal control byte (reported on fail).
                    run('send-keys', 'C-a')
                    time.sleep(.2)
                feed(escape)
                try:
                    current = mode('n')
                except AssertionError:
                    print('FAIL:', repr(opener), state(), flush=True)
                    raise
                assert current['line'] in ('alpha probe beta', 'another probe'), current
                assert not current['ex_executed'], 'Canceled Ex command executed'
                print('PASS: Escape cancels', repr(opener), 'encoded=' + str(args.encoded_escape), flush=True)
            type_text(b'/another\r')
            until(lambda: state().get('mode') == 'n' and state().get('search') == 'another'
                  and state().get('cursor') == [2, 0],
                  'Search Enter did not preserve search: ' + repr(state()))
            print('PASS: Enter confirms search pattern', flush=True)
            type_text(b'/cancel')
            mode('c')
            feed(b'\x03')
            mode('n')
            print('PASS: Ctrl-C cancels search', flush=True)
        finally:
            pids = []
            for path in (temp / 'runtime').rglob('*.pid'):
                try:
                    pids.append(int(path.read_text().strip()))
                except (FileNotFoundError, ValueError):
                    pass
            try:
                run('kill-session', '-t', '=search', check=False)
                until(lambda: not any(alive(pid) for pid in pids), 'Private server failed to terminate')
            finally:
                try:
                    if process is not None:
                        control('QUIT')
                        try:
                            process.wait(timeout=10)
                        except subprocess.TimeoutExpired:
                            process.terminate()
                            process.wait(timeout=5)
                finally:
                    assert lock.read_bytes() == before, 'User lockfile changed'
            print('PASS: private server terminated; user lockfile preserved', flush=True)
    print('Physical keyboard, IME and other OS behavior remain unverified; Noice tested only with --full-config.')


if __name__ == '__main__':
    main()
