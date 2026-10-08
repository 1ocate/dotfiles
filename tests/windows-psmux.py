"""Native psmux + current navigator integration. Existing tools only, isolated servers."""
import argparse
import json
import ctypes
from ctypes import wintypes
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def until(predicate, description, timeout=25):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        value = predicate()
        if value:
            return value
        time.sleep(0.1)
    raise AssertionError(description)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--full-config', action='store_true', help='Load current LazyVim config offline; disable bytecode cache and tool downloads.')
    args = parser.parse_args()
    if os.name != 'nt':
        raise SystemExit('Native Windows is required.')
    binary = Path(os.environ['LOCALAPPDATA']) / 'Programs/psmux/3.3.8/psmux.exe'
    nvim = shutil.which('nvim')
    pwsh = shutil.which('pwsh')
    plugin = Path(os.environ['LOCALAPPDATA']) / 'nvim-data/lazy/nvim-tmux-navigation'
    if not binary.is_file() or not nvim or not pwsh or not plugin.is_dir():
        raise SystemExit('Installed psmux 3.3.8, Neovim, PowerShell 7 and navigator are required; no downloads.')
    startup = ['-u', 'NONE']
    if args.full_config:
        # Keep the existing installed plugin state, with no bootstrap/download/update.
        # Disable Lua bytecode caching to exclude the existing Windows long-path issue.
        guard = (
            "lua vim.loader.enable(false); vim.loader.enable=function() end; "
            "vim.opt.rtp:prepend(vim.env.LOCALAPPDATA..'/nvim-data/lazy/lazy.nvim'); "
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
        startup = ['--cmd', guard, '-u', str(ROOT / 'nvim/init.lua')]
    lock_before = (ROOT / 'nvim/lazy-lock.json').read_bytes()
    with tempfile.TemporaryDirectory(prefix='dotfiles-psmux-test-', ignore_cleanup_errors=True) as temporary:
        temp = Path(temporary)
        env = os.environ.copy()
        env.pop('TMUX', None)
        env.pop('TMUX_PANE', None)
        for key in list(env):
            if key.startswith('PSMUX_'):
                env.pop(key)
        env.update(PSMUX_DATA_DIR=str(temp / 'runtime'), PSMUX_NO_WARM='1',
                   DOTFILES_ROOT=str(ROOT), DOTFILES_PSMUX_ROOT=str(ROOT),
                   DOTFILES_PSMUX_FULL='1' if args.full_config else '0',
                   DOTFILES_PSMUX_EXE=str(binary), DOTFILES_PSMUX_WAIT=str(temp / 'wait.ps1'),
                   DOTFILES_PSMUX_RESULT=str(temp / 'headless.json'))
        env['PATH'] = str(binary.parent) + ';' + env['PATH']
        (temp / 'wait.ps1').write_text('Start-Sleep -Seconds 180\n', encoding='utf-8-sig')

        def run(*args, check=True):
            result = subprocess.run([str(binary), *args], env=env,
                                    capture_output=True, text=True, encoding='utf-8', timeout=30)
            if check and result.returncode:
                raise AssertionError(f'{args[0]} failed: {result.stderr}')
            return result.stdout.strip()

        def server_running(pid):
            kernel = ctypes.WinDLL('kernel32', use_last_error=True)
            kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
            kernel.OpenProcess.restype = wintypes.HANDLE
            kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
            kernel.CloseHandle.argtypes = [wintypes.HANDLE]
            handle = kernel.OpenProcess(0x100000, False, pid)  # SYNCHRONIZE only.
            if not handle:
                return False
            try:
                return kernel.WaitForSingleObject(handle, 0) == 258  # WAIT_TIMEOUT.
            finally:
                kernel.CloseHandle(handle)

        def cleanup_servers():
            pids = []
            for path in (temp / 'runtime').rglob('*.pid'):
                try:
                    pids.append(int(path.read_text().strip()))
                except (ValueError, FileNotFoundError):
                    pass
            # Private data directory; terminate only sessions this fixture creates.
            for name in ('probe', 'live', 'other'):
                run('kill-session', '-t', '=' + name, check=False)
            until(lambda: not any(server_running(pid) for pid in pids),
                  'Isolated test server did not terminate', timeout=10)
            time.sleep(1)  # ConPTY releases cwd handles asynchronously.

        def load_state(path):
            try:
                return json.loads(path.read_text(encoding='utf-8'))
            except (FileNotFoundError, json.JSONDecodeError):
                return None

        input_host = None
        input_dir = temp / 'input-host'
        input_dir.mkdir()
        csc = Path(os.environ['WINDIR']) / 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
        if not csc.is_file():
            raise SystemExit('Windows .NET Framework C# compiler is required; no downloads.')
        host_exe = temp / 'psmux-input-host.exe'
        subprocess.run([str(csc), '/nologo', '/out:' + str(host_exe),
                        str(ROOT / 'tests/psmux-input-host.cs')], check=True,
                       capture_output=True, text=True, timeout=30)
        def terminal_bytes(data):
            with (input_dir / 'conpty_ctrl.txt').open('a', encoding='ascii') as control:
                control.write('HEX ' + data.hex() + '\n')

        try:
            run('-f', str(ROOT / 'tmux/psmux.conf'), 'new-session', '-d', '-s', 'probe',
                '-x', '120', '-y', '40', '--', nvim, '--headless', *startup, '-i', 'NONE',
                '-S', str(ROOT / 'tests/windows-psmux.lua'))
            headless = until(lambda: load_state(temp / 'headless.json'), 'Headless navigator did not finish')
            assert headless['setup_ok'], headless.get('setup_error')
            for test in headless['tests']:
                assert test['ok'], test
                print('PASS:', test['name'])
            cleanup_servers()  # Only named fixture sessions in the isolated data directory.

            # Live Neovim plus a genuinely attached psmux client. Feed raw terminal
            # bytes through a second ConPTY, exercising client key decoding/bindings.
            # Desktop focus, WezTerm and IME remain separate physical checks.
            live_path = temp / 'live.json'
            live_script = temp / 'live.lua'
            live_script.write_text("""
local root=assert(vim.env.DOTFILES_PSMUX_ROOT)
if vim.env.DOTFILES_PSMUX_FULL == '1' then
  require('lazy').load({plugins={'nvim-tmux-navigation'}})
else
  vim.g.dotfiles_environment='windows-powershell'
  dofile(root..'/nvim/lua/config/options.lua')
  vim.opt.rtp:prepend(root..'/nvim')
  vim.opt.rtp:prepend(vim.env.LOCALAPPDATA..'/nvim-data/lazy/nvim-tmux-navigation')
  dofile(root..'/nvim/lua/plugins/vim-tmux-navigator.lua').config()
end
-- Mimic an LSP/terminal child that must not steal the foreground identity.
vim.fn.jobstart({'pwsh','-NoProfile','-File',vim.env.DOTFILES_PSMUX_WAIT})
if vim.env.DOTFILES_PSMUX_FULL ~= '1' then vim.opt.backspace={'indent','eol','start'} end
vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true,false))
vim.cmd('vsplit')
vim.cmd('wincmd l')
local prepare_count=0
local timer=vim.uv.new_timer()
timer:start(100,100,vim.schedule_wrap(function()
  local prepare=vim.env.DOTFILES_PSMUX_LIVE..'.insert'
  if vim.fn.filereadable(prepare) == 1 then
    vim.fn.delete(prepare)
    local buffer=vim.api.nvim_create_buf(true,false)
    prepare_count=prepare_count+1
    vim.api.nvim_buf_set_name(buffer,vim.env.DOTFILES_PSMUX_LIVE..'.'..prepare_count..'.txt')
    vim.api.nvim_set_current_buf(buffer)
    vim.api.nvim_set_current_line('ab'); vim.cmd('startinsert!')
  end
  if vim.fn.filereadable(vim.env.DOTFILES_PSMUX_LIVE..'.quit') == 1 then
    vim.cmd('qa!') -- Fixture cleanup after all attached-client input assertions.
    return
  end
  local terminal=vim.env.DOTFILES_PSMUX_LIVE..'.terminal'
  if vim.fn.filereadable(terminal) == 1 then
    vim.fn.delete(terminal)
    vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true,false))
    vim.fn.jobstart({'pwsh','-NoProfile','-File',vim.env.DOTFILES_PSMUX_WAIT},{term=true})
    vim.cmd('startinsert')
  end
  vim.fn.writefile({vim.json.encode({win=vim.api.nvim_get_current_win(),count=#vim.api.nvim_list_wins(),pane=vim.env.TMUX_PANE,line=vim.api.nvim_get_current_line(),mode=vim.api.nvim_get_mode().mode})},vim.env.DOTFILES_PSMUX_LIVE)
end))
""", encoding='utf-8')
            shell_script = temp / 'live.ps1'
            quote = lambda value: "'" + str(value).replace("'", "''") + "'"
            shell_script.write_text('& ' + quote(nvim) + ' ' + ' '.join(map(quote, [*startup, '-i', 'NONE', '-S', str(live_script)])) + '\nStart-Sleep -Seconds 180\n', encoding='utf-8-sig')
            env['DOTFILES_PSMUX_LIVE'] = str(live_path)
            cwd = temp / 'project 한글 space'
            cwd.mkdir()
            run('-f', str(ROOT / 'tmux/psmux.conf'), 'new-session', '-d', '-s', 'live',
                '-c', str(cwd), '-x', '120', '-y', '40', '--', pwsh, '-NoProfile', '-File', str(shell_script))
            state = until(lambda: load_state(live_path), 'Live Neovim did not initialize')
            original = state['pane']
            run('split-window', '-h', '-d', '-t', original, '--', pwsh, '-NoProfile', '-File', str(temp / 'wait.ps1'))
            run('select-pane', '-t', original)
            command = run('display-message', '-p', '#{pane_current_command}')
            assert command.lower().removesuffix('.exe') == 'nvim', command
            condition = "#{m/ri:(^|[/\\\\ ])(g?view|g?n?vim|fzf)([.]exe)?( |$),#{pane_current_command}}"
            assert run('display-message', '-p', condition) == '1', 'Native Neovim foreground matcher failed'
            print('PASS: foreground remains Neovim with an LSP-like child process')
            env['DOTFILES_PROBE_DIR'] = str(input_dir)
            command_line = subprocess.list2cmdline([str(binary),
                                                  'attach-session', '-t', '=live'])
            startupinfo = subprocess.STARTUPINFO()
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startupinfo.wShowWindow = 0  # Hidden test helper console only.
            input_host = subprocess.Popen([str(host_exe), command_line], env=env,
                                          startupinfo=startupinfo,
                                          creationflags=subprocess.CREATE_NEW_CONSOLE)
            until(lambda: (input_dir / 'conpty_childpid.txt').exists(),
                  'ConPTY attached client did not start')
            until(lambda: run('list-clients'), 'Real psmux client did not attach')
            def dispatch(name):
                # CLI dispatch checks the binding action, not physical decoding.
                run('if-shell', '-F', condition, 'send-keys ' + name,
                    'select-pane ' + {'C-h':'-L', 'C-j':'-D', 'C-k':'-U', 'C-l':'-R'}[name])

            def press(name):
                terminal_bytes({'C-h': b'\x1bh', 'C-j': b'\x0a', 'C-k': b'\x0b', 'C-l': b'\x0c'}[name])

            before_win = state['win']
            press('C-h')
            until(lambda: (current := load_state(live_path)) and current.get('win') != before_win,
                  'Alt-h-encoded Ctrl-h did not reach Neovim internal split')
            assert run('display-message', '-p', '#{pane_id}') == original
            print('PASS: attached-client Alt-h-encoded Ctrl-h forwards to internal Neovim split')
            press('C-l')
            until(lambda: (load_state(live_path) or {}).get('win') == before_win,
                  'Raw Ctrl-l input did not return to right split')
            press('C-l')
            until(lambda: run('display-message', '-p', '#{pane_id}') != original,
                  'Neovim did not leave for the neighboring pane')
            print('PASS: raw Ctrl-l input traverses Neovim then psmux')
            assert run('display-message', '-p', condition) == '0'
            press('C-h')
            until(lambda: run('display-message', '-p', '#{pane_id}') == original,
                  'Shell Alt-h-encoded Ctrl-h did not select Neovim pane')
            print('PASS: attached-client shell Alt-h-encoded Ctrl-h returns to Neovim')
            left = run('split-window', '-h', '-d', '-P', '-F', '#{pane_id}', '-t', original,
                       '--', pwsh, '-NoProfile', '-File', str(temp / 'wait.ps1'))
            # psmux 3.3.8 ignores split-window -b horizontally; place panes explicitly.
            run('swap-pane', '-s', original, '-t', left)
            run('select-pane', '-t', original)
            assert int(run('display-message', '-p', '-t', left, '#{pane_left}')) < int(run('display-message', '-p', '-t', original, '#{pane_left}'))
            Path(str(live_path) + '.insert').write_text('prepare', encoding='ascii')
            until(lambda: (current := load_state(live_path)) and current.get('mode', '').startswith('i') and current.get('line') == 'ab',
                  'Insert-mode left navigation preparation failed')
            press('C-h')
            until(lambda: (load_state(live_path) or {}).get('win') != before_win,
                  'Encoded Ctrl-h did not leave insert mode for the left internal split')
            press('C-h')
            until(lambda: run('display-message', '-p', '#{pane_id}') == left,
                  'Encoded Ctrl-h did not move to the left shell pane: ' + run('list-panes', '-F', '#{pane_id} #{pane_left} #{pane_active}'))
            assert (load_state(live_path) or {}).get('mode') == 'n'
            run('select-pane', '-t', original)
            run('kill-pane', '-t', left)
            press('C-l')
            until(lambda: (load_state(live_path) or {}).get('win') == before_win,
                  'Could not return to the right internal split')
            assert (load_state(live_path) or {}).get('line') == 'ab'
            print('PASS: encoded Ctrl-h leaves insert mode and traverses left splits without deleting text')
            # Ordinary Backspace (DEL) must still edit, never select another pane.
            assert (load_state(live_path) or {}).get('mode') == 'n'
            Path(str(live_path) + '.insert').write_text('prepare', encoding='ascii')
            try:
                until(lambda: (current := load_state(live_path)) and current.get('mode', '').startswith('i') and current.get('line') == 'ab',
                      'Backspace test insert preparation failed')
            except AssertionError:
                print('Insert preparation state:', load_state(live_path), flush=True)
                raise
            terminal_bytes(b'\x7f')
            until(lambda: (load_state(live_path) or {}).get('line') == 'a', 'Ordinary Backspace did not delete the inserted character')
            # Regression: repeated control bytes can wedge a subsequent raw Escape.
            # CLI bytes prepare the broken editor state without invoking navigation.
            run('send-keys', 'C-l', 'C-l', 'C-l', 'C-l')
            until(lambda: (load_state(live_path) or {}).get('line') == 'a' + '\x0c' * 4,
                  'Repeated control-input regression preparation failed')
            terminal_bytes(b'\x1b')
            until(lambda: (load_state(live_path) or {}).get('mode') == 'n', 'Editor did not leave insert mode')
            assert run('display-message', '-p', '#{pane_id}') == original
            assert (load_state(live_path) or {}).get('win') == before_win
            print('PASS: ordinary Backspace edits without pane navigation')
            print('PASS: raw single Escape recovers after split and repeated Ctrl-l input')
            run('split-window', '-v', '-t', original, '--', pwsh, '-NoProfile', '-File', str(temp / 'wait.ps1'))
            below = run('display-message', '-p', '#{pane_id}')
            press('C-k')
            until(lambda: run('display-message', '-p', '#{pane_id}') == original,
                  'Raw Ctrl-k did not move from lower shell pane to upper Neovim pane')
            dispatch('C-j')
            until(lambda: run('display-message', '-p', '#{pane_id}') == below,
                  'CLI Ctrl-j dispatch did not move from upper Neovim pane to lower shell pane')
            press('C-k')
            until(lambda: run('display-message', '-p', '#{pane_id}') == original,
                  'Raw Ctrl-k did not return to upper Neovim pane')
            run('kill-pane', '-t', below)
            print('PASS: raw Ctrl-k and CLI Ctrl-j traverse vertically split Neovim and shell panes')
            above = run('split-window', '-v', '-b', '-d', '-P', '-F', '#{pane_id}', '-t', original,
                        '--', pwsh, '-NoProfile', '-File', str(temp / 'wait.ps1'))
            assert above and above != original
            Path(str(live_path) + '.insert').write_text('prepare', encoding='ascii')
            until(lambda: (current := load_state(live_path)) and current.get('mode', '').startswith('i') and current.get('line') == 'ab',
                  'Insert-mode upward navigation preparation failed')
            press('C-k')
            until(lambda: run('display-message', '-p', '#{pane_id}') == above,
                  'Insert-mode raw Ctrl-k did not navigate to the upper shell pane')
            until(lambda: (load_state(live_path) or {}).get('mode') == 'n',
                  'Ctrl-k did not leave insert mode')
            assert (load_state(live_path) or {}).get('line') == 'ab'
            run('select-pane', '-t', original)
            run('kill-pane', '-t', above)
            print('PASS: raw Ctrl-k leaves insert mode and navigates upward without inserting control characters')
            Path(str(live_path) + '.insert').write_text('prepare', encoding='ascii')
            until(lambda: (current := load_state(live_path)) and current.get('mode', '').startswith('i') and current.get('line') == 'ab',
                  'Insert-mode right navigation preparation failed')
            terminal_bytes(b'\x0c' * 4)
            until(lambda: (load_state(live_path) or {}).get('mode') == 'n',
                  'Repeated raw Ctrl-l did not leave insert mode')
            assert (load_state(live_path) or {}).get('line') == 'ab'
            run('select-pane', '-t', original)
            print('PASS: repeated raw Ctrl-l navigation never inserts literal control characters')
            assert run('show-options', '-gv', 'prefix') == 'C-Space'
            run('split-window', '-h', '-c', '#{pane_current_path}')
            assert len(run('list-panes', '-F', '#{pane_id}').splitlines()) == 3
            new_cwd = run('display-message', '-p', '#{pane_current_path}')
            assert Path(new_cwd).resolve() == cwd.resolve(), new_cwd
            print('PASS: configured prefix and split action preserve Korean/space directory')
            run('select-pane', '-t', original)
            Path(str(live_path) + '.insert').write_text('prepare', encoding='ascii')
            until(lambda: (current := load_state(live_path)) and current.get('mode', '').startswith('i') and current.get('line') == 'ab',
                  'Insert-to-terminal preparation failed')
            Path(str(live_path) + '.terminal').write_text('prepare', encoding='ascii')
            until(lambda: (load_state(live_path) or {}).get('mode') == 't',
                  'Neovim terminal did not enter terminal-input mode')
            assert run('display-message', '-p', '#{pane_current_command}') == 'nvim', 'Terminal retained insert marker'
            terminal_bytes(b'\x1b')
            time.sleep(0.5)
            assert (load_state(live_path) or {}).get('mode') == 't', 'Escape incorrectly forced terminal mode to normal'
            print('PASS: insert-to-terminal transition resets marker and preserves terminal Escape')
            Path(str(live_path) + '.quit').write_text('quit', encoding='ascii')
            until(lambda: run('display-message', '-p', '#{pane_current_command}').lower().removesuffix('.exe') == 'pwsh',
                  'Editor exit did not clear psmux foreground identity')
            print('PASS: Neovim exit restores shell foreground identity')
            with (input_dir / 'conpty_ctrl.txt').open('a', encoding='ascii') as control:
                control.write('QUIT\n')
            input_host.wait(timeout=15)
            input_host = None
            run('has-session', '-t', '=live')
            print('PASS: session survives attached terminal closure')
        finally:
            if input_host is not None:
                with (input_dir / 'conpty_ctrl.txt').open('a', encoding='ascii') as control:
                    control.write('QUIT\n')
                try:
                    input_host.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    input_host.kill()  # Only the helper process created above.
                    input_host.wait(timeout=5)
            cleanup_servers()
    assert (ROOT / 'nvim/lazy-lock.json').read_bytes() == lock_before, 'User lockfile changed'
    print('PASS: test server termination confirmed; user lockfile preserved')
    if temp.exists():
        print('NOTE: temporary files retained while Windows releases handles:', temp)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
