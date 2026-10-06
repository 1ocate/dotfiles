-- Windows psmux foreground identity. LSP/jobs must not hide their Neovim parent.
local M = {}
function M.setup()
  local tmux = vim.env.TMUX or ''
  if vim.fn.has('win32') ~= 1 or vim.g.dotfiles_environment ~= 'windows-powershell'
      or not (tmux:find('/dotfiles,', 1, true) or tmux:find('/dotfiles-test-', 1, true)) then
    return
  end
  -- psmux v3.3.8 reads OSC 133 command markers before its process-tree fallback.
  local function enter()
    io.stderr:write('\27]133;C;cmdline_url=nvim\7')
    io.stderr:flush()
  end
  local function leave()
    io.stderr:write('\27]133;D\7')
    io.stderr:flush()
  end
  local group = vim.api.nvim_create_augroup('DotfilesPsmuxForeground', { clear = true })
  vim.api.nvim_create_autocmd({ 'VimEnter', 'VimResume' }, { group = group, callback = enter })
  vim.api.nvim_create_autocmd({ 'VimLeavePre', 'VimSuspend' }, { group = group, callback = leave })
  enter() -- VeryLazy may load after VimEnter.
end
return M
