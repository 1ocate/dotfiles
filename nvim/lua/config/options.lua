-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- vim 클립보드 연동 해제
vim.cmd("set clipboard=")
-- vim.opt.cursorline = true
-- vim.opt.cursorcolumn = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.cindent = true
vim.opt.autoindent = true
vim.opt.smartindent = true

vim.opt.fileencodings = "utf-8,euc-kr"

vim.opt.updatetime = 4000

vim.opt.wrap = false

vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.wildmode = "longest:full,full" -- complete the longest common match, and allow tabbing the results to fully complete them

vim.opt.title = true
vim.opt.mouse = "a" -- enable mouse for all modes

vim.opt.termguicolors = true

-- vim.opt.spell = true

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.list = true -- enable the below listchars
vim.opt.listchars = { tab = "▸ ", trail = "·" }
vim.opt.fillchars:append({ eob = " " }) -- remove the ~ from end of buffer

vim.opt.splitbelow = true
vim.opt.splitright = true

vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8

-- vim.opt.clipboard = 'unnamedplus' -- Use system clipboard
vim.opt.confirm = true -- ask for confirmation instead of erroring
vim.opt.undofile = true -- persistent undo
vim.opt.backupdir:remove(".") -- keep backups out of the current directory
vim.opt.backup = true -- automatically save a backup file

-- for WSL
if osName == "WSL" then
  vim.cmd([[
      set noeol
      set nofixeol
    ]])
end

-- for buffer
-- vim.opt.hidden = true
--
-- LSP Server to use for PHP.
-- Set to "intelephense" to use intelephense instead of phpactor.
vim.g.lazyvim_php_lsp = "intelephense"
