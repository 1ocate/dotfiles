local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

require('packer').reset()
require('packer').init({
  compile_path = vim.fn.stdpath('data')..'/site/plugin/packer_compiled.lua',
 display = {
   open_fn = function()
     return require('packer.util').float({ border = 'solid' })
   end,
 },
})

local use = require('packer').use

-- Packer can manage itself.
use('wbthomason/packer.nvim')

-- Commenting support.
use('tpope/vim-commentary')

-- Add, change, and delete surrounding text.
use("tpope/vim-surround")

-- Useful commands like :Rename and :SudoWrite.
use('tpope/vim-eunuch')

-- Pairs of handy bracket mappings, like [b and ]b.
use('tpope/vim-unimpaired')

-- Indent autodetection with editorconfig support.
use('tpope/vim-sleuth')

-- Allow plugins to enable repeating of commands.
use('tpope/vim-repeat')

-- Add more languages.
use('sheerun/vim-polyglot')

-- Navigate seamlessly between Vim windows and Tmux panes.
use('christoomey/vim-tmux-navigator')

-- Jump to the last location when opening a file.
use('farmergreg/vim-lastplace')

-- Enable * searching with visually selected text.
use('nelstrom/vim-visual-star-search')

-- Automatically create parent dirs when saving.
use('jessarcher/vim-heritage')

-- Text objects for HTML attributes.
use({
  'whatyouhide/vim-textobj-xmlattr',
  requires = 'kana/vim-textobj-user',
})

-- Automatically set the working directory to the project root.
use({
  'airblade/vim-rooter',
  setup = function()
    -- Instead of this running every time we open a file, we'll just run it once when Vim starts.
    vim.g.rooter_manual_only = 1
  end,
  config = function()
    vim.cmd('Rooter')
  end,
})

-- Automatically add closing brackets, quotes, etc.
use({
  'windwp/nvim-autopairs',
  config = function()
    require('nvim-autopairs').setup{
      map_cr = false,
    }
  end,
})

-- Add smooth scrolling to avoid jarring jumps
use({
  'karb94/neoscroll.nvim',
  config = function()
    require('neoscroll').setup()
  end,
})

-- All closing buffers without closing the split window.
use({
  'famiu/bufdelete.nvim',
  config = function()
    vim.keymap.set('n', '<Leader>q', ':Bdelete<CR>')
  end,
})

-- Split arrays and methods onto multiple lines, or join them back up.
use({
  'AndrewRadev/splitjoin.vim',
  config = function()
    vim.g.splitjoin_html_attributes_bracket_on_new_line = 1
    vim.g.splitjoin_trailing_comma = 1
    vim.g.splitjoin_php_method_chain_full = 1
  end,
})

-- Automatically fix indentation when pasting code.
use({
  'sickill/vim-pasta',
  config = function()
    vim.g.pasta_disabled_filetypes = { 'fugitive' }
  end,
})

-- Clipboard system sync only yank.
use({
  '1ocate/yankclip.vim',
  config = function()
    vim.g.os_clipboard_enble = 1
    vim.keymap.set('n', '<F9>', ':OsYankToggle <CR>')
  end,
})

-- gruvbox theme.
use({
    'morhetz/gruvbox',
  config = function()
    vim.g.gruvbox_contrast_dark = 'hard'
    vim.g.gruvbox_italic = 1
    vim.opt.background = 'dark'
    vim.cmd('colorscheme gruvbox')

    vim.api.nvim_set_hl(0, 'FloatBorder', {
      fg = vim.api.nvim_get_hl_by_name('NormalFloat', true).background,
      bg = vim.api.nvim_get_hl_by_name('NormalFloat', true).background,
    })
  end,

})

-- Vim bible
use({
  'robertrosman/vim-bible',
  config = function()
    vim.g.BibleTranslation = 'KorRv'
    vim.g.BibleLocale = 'en'
    vim.cmd([[
      "noremap <Leader>b y :d_ <bar> :call bible#insert_quote(substitute(@", '\n$', '', ''))<CR>
      vnoremap <Leader>b y :d_ <bar> :call bible#insert_quote(substitute(@", '\n$', '', ''))<CR>
    ]])
  end,
})

-- Fuzzy finder
use({
  'nvim-telescope/telescope.nvim',
  requires = {
    'nvim-lua/plenary.nvim',
    'kyazdani42/nvim-web-devicons',
    'nvim-telescope/telescope-live-grep-args.nvim',
    { 'nvim-telescope/telescope-fzf-native.nvim', run = 'make' },
  },
  config = function()
    require('user/plugins/telescope')
  end,
})

-- File tree sidebar
use({
  'kyazdani42/nvim-tree.lua',
  requires = 'kyazdani42/nvim-web-devicons',
  config = function()
    require('user/plugins/nvim-tree')
  end,
})

-- Git integration.
use({
  'lewis6991/gitsigns.nvim',
  config = function()
    require('gitsigns').setup()
    vim.keymap.set('n', ']h', ':Gitsigns next_hunk<CR>')
    vim.keymap.set('n', '[h', ':Gitsigns prev_hunk<CR>')
    vim.keymap.set('n', 'gs', ':Gitsigns stage_hunk<CR>')
    vim.keymap.set('n', 'gS', ':Gitsigns undo_stage_hunk<CR>')
    vim.keymap.set('n', 'gp', ':Gitsigns preview_hunk<CR>')
    vim.keymap.set('n', 'gb', ':Gitsigns blame_line<CR>')
  end,
})

-- Vim Fugitive
use({
  'tpope/vim-fugitive',
  requires = 'tpope/vim-rhubarb',
})

--- Floating terminal.
use({
  'voldikss/vim-floaterm',
  config = function()
    vim.g.floaterm_width = 0.8
    vim.g.floaterm_height = 0.8
    vim.keymap.set('n', '<F1>', ':FloatermToggle<CR>')
    vim.keymap.set('t', '<F1>', '<C-\\><C-n>:FloatermToggle<CR>')
    vim.keymap.set('t', '<F2>', '<C-\\><C-n>')
    vim.cmd([[
      highlight link Floaterm CursorLine
      highlight link FloatermBorder CursorLineBg
    ]])
  end
})

-- Vim Test
use({
  'vim-test/vim-test',
  config = function()
    require('user.plugins.vim-test')
  end,
})

-- bufferline
use({
  'akinsho/bufferline.nvim',
  requires = 'kyazdani42/nvim-web-devicons',
  after = 'gruvbox',
  config = function()
    require('user.plugins.bufferline')
  end,
})

-- Improved syntax highlighting
use({
  'nvim-treesitter/nvim-treesitter',
  run = function()
    require('nvim-treesitter.install').update({ with_sync = true })
  end,
  requires = {
    'JoosepAlviste/nvim-ts-context-commentstring',
    'nvim-treesitter/nvim-treesitter-textobjects',
  },
  config = function()
    require('user/plugins/treesitter')
  end,
})

-- Lualine
use({
  'nvim-lualine/lualine.nvim',
  requires = 'kyazdani42/nvim-web-devicons',
  config = function()
    require('user.plugins.lualine')
  end,
})


--fzf
use { 'junegunn/fzf', run = ":call fzf#install()" }
use ({ 
    'junegunn/fzf.vim',
    config = function()
      require('user.plugins.fzf')
    end,
})

--COC
use ({
    'neoclide/coc.nvim', branch = 'release',
    config = function()
      require('user.plugins.coc')
    end,
  })

-- Rainbow bracket
use({
    'luochen1990/rainbow',
  config = function()
    vim.g.rainbow_active = 1
    vim.api.nvim_set_hl(0, "@punctuation.bracket", { link = "" })
  end,
})

-- Put this at the end after all plugins
if packer_bootstrap then
    require('packer').sync()
end

vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile>
  augroup end
]])
