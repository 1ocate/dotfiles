"""Native psmux + current navigator integration. Existing tools only, isolated servers."""
import argparse
import json
import ctypes
from ctypes import wintypes
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import time
import uuid

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
    namespace = 'dotfiles-test-' + uuid.uuid4().hex[:8]
    with tempfile.TemporaryDirectory(prefix='dotfiles-psmux-test-', ignore_cleanup_errors=True) as temporary:
        temp = Path(temporary)
        env = os.environ.copy()
        env.pop('TMUX', None)
        env.pop('TMUX_PANE', None)
        env.update(PSMUX_DATA_DIR=str(temp / 'runtime'), PSMUX_NO_WARM='1',
                   DOTFILES_PSMUX_NAMESPACE=namespace, DOTFILES_PSMUX_ROOT=str(ROOT),
                   DOTFILES_PSMUX_FULL='1' if args.full_config else '0',
                   DOTFILES_PSMUX_EXE=str(binary), DOTFILES_PSMUX_WAIT=str(temp / 'wait.ps1'),
                   DOTFILES_PSMUX_RESULT=str(temp / 'headless.json'))
        env['PATH'] = str(binary.parent) + ';' + env['PATH']
        (temp / 'wait.ps1').write_text('Start-Sleep -Seconds 180\n', encoding='utf-8-sig')

        def run(*args, check=True):
            result = subprocess.run([str(binary), '-L', namespace, *args], env=env,
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
            run('kill-server', check=False)  # No server may exist after an early failure.
            until(lambda: not any(server_running(pid) for pid in pids),
                  'Test namespace server did not terminate', timeout=10)
            time.sleep(1)  # ConPTY releases cwd handles asynchronously.

        def load_state(path):
            try:
                return json.loads(path.read_text(encoding='utf-8'))
            except (FileNotFoundError, json.JSONDecodeError):
                return None

        try:
            run('-f', str(ROOT / 'tmux/psmux.conf'), 'new-session', '-d', '-s', 'probe',
                '-x', '120', '-y', '40', '--', nvim, '--headless', *startup, '-i', 'NONE',
                '-S', str(ROOT / 'tests/windows-psmux.lua'))
            headless = until(lambda: load_state(temp / 'headless.json'), 'Headless navigator did not finish')
            assert headless['setup_ok'], headless.get('setup_error')
            for test in headless['tests']:
                assert test['ok'], test
                print('PASS:', test['name'])
            cleanup_servers()  # Always this unique -L namespace and isolated data directory.

            # Live Neovim in ConPTY. Dispatch the exact root binding command that
            # an attached psmux client sends; physical terminal keys remain untested.
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
vim.cmd('vsplit')
vim.cmd('wincmd l')
local timer=vim.uv.new_timer()
timer:start(100,100,vim.schedule_wrap(function()
  vim.fn.writefile({vim.json.encode({win=vim.api.nvim_get_current_win(),count=#vim.api.nvim_list_wins(),pane=vim.env.TMUX_PANE})},vim.env.DOTFILES_PSMUX_LIVE)
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
            root_bindings = {}
            for line in (ROOT / 'tmux/psmux.conf').read_text(encoding='utf-8-sig').splitlines():
                tokens = shlex.split(line)
                if tokens[:2] == ['bind', '-n']:
                    root_bindings[tokens[2]] = tokens[3:]
            def press(name):
                assert name in root_bindings
                run(*root_bindings[name])

            before_win = state['win']
            press('C-h')
            until(lambda: (current := load_state(live_path)) and current.get('win') != before_win,
                  'Root Ctrl-h command did not reach Neovim internal split')
            assert run('display-message', '-p', '#{pane_id}') == original
            print('PASS: root Ctrl-h command forwards to internal Neovim split')
            press('C-l')
            until(lambda: (load_state(live_path) or {}).get('win') == before_win,
                  'Root Ctrl-l command did not return to right split')
            press('C-l')
            until(lambda: run('display-message', '-p', '#{pane_id}') != original,
                  'Neovim did not leave for the neighboring pane')
            print('PASS: root Ctrl-l command traverses Neovim then psmux')
            assert run('display-message', '-p', condition) == '0'
            press('C-h')
            until(lambda: run('display-message', '-p', '#{pane_id}') == original,
                  'Shell root Ctrl-h command did not select Neovim pane')
            print('PASS: shell root Ctrl-h command returns to Neovim')
            assert run('show-options', '-gv', 'prefix') == 'C-Space'
            run('split-window', '-h', '-c', '#{pane_current_path}')
            assert len(run('list-panes', '-F', '#{pane_id}').splitlines()) == 3
            new_cwd = run('display-message', '-p', '#{pane_current_path}')
            assert Path(new_cwd).resolve() == cwd.resolve(), new_cwd
            print('PASS: configured prefix and split action preserve Korean/space directory')
            run('select-pane', '-t', original)
            run('send-keys', '-t', original, ':qa!', 'Enter')
            until(lambda: run('display-message', '-p', '#{pane_current_command}').lower().removesuffix('.exe') == 'pwsh',
                  'Editor exit did not clear psmux foreground identity')
            print('PASS: Neovim exit restores shell foreground identity')
            # No GUI client is attached in this test. Session survival is checked
            # after a short control connection closes, not claimed as GUI detach.

            run('has-session', '-t', '=live')
            print('PASS: session survives control connection closure')
        finally:
            cleanup_servers()
    assert (ROOT / 'nvim/lazy-lock.json').read_bytes() == lock_before, 'User lockfile changed'
    print('PASS: test server termination confirmed; user lockfile preserved')
    if temp.exists():
        print('NOTE: temporary files retained while Windows releases handles:', temp)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
