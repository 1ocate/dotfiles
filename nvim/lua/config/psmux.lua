-- Windows psmux foreground identity. LSP/jobs must not hide their Neovim parent.
local M = {}
function M.setup()
  local tmux = vim.env.TMUX or ''
  if vim.fn.has('win32') ~= 1 or vim.g.dotfiles_environment ~= 'windows-powershell'
      or not tmux:match('^/tmp/psmux%-%d+/default,%d+,0$')
      or not vim.env.PSMUX_SESSION or vim.env.PSMUX_SESSION == '' then
    return
  end
  local root, config = vim.env.DOTFILES_ROOT, vim.env.PSMUX_CONFIG_FILE
  local function absolute(path)
    return type(path) == 'string' and (path:match('^%a:[/\\]') or path:match('^[/\\][/\\]'))
  end
  if not absolute(root) or not absolute(config) then return end
  local function normalize(path)
    return vim.fn.fnamemodify(path, ':p'):gsub('\\', '/'):gsub('/+$', ''):lower()
  end
  if normalize(config) ~= normalize(root .. '/tmux/psmux.conf') then return end
  -- psmux v3.3.8 reads OSC 133 command markers before its process-tree fallback.
  local function enter(command)
    command = command or (vim.api.nvim_get_mode().mode:match('^[iR]') and 'nvim-insert' or 'nvim')
    io.stderr:write('\27]133;C;cmdline_url=' .. command .. '\7')
    io.stderr:flush()
  end
  local function leave()
    io.stderr:write('\27]133;D\7')
    io.stderr:flush()
  end
  local group = vim.api.nvim_create_augroup('DotfilesPsmuxForeground', { clear = true })
  vim.api.nvim_create_autocmd({ 'VimEnter', 'VimResume' }, { group = group, callback = function() enter() end })
  vim.api.nvim_create_autocmd({ 'VimLeavePre', 'VimSuspend' }, { group = group, callback = leave })
  vim.api.nvim_create_autocmd('InsertEnter', { group = group, callback = function() enter('nvim-insert') end })
  vim.api.nvim_create_autocmd('InsertLeave', { group = group, callback = function() enter('nvim') end })
  enter() -- VeryLazy may load after VimEnter.
end
return M
