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
use({
  'tpope/vim-sleuth',
  config = function()
    vim.b.sleuth_automatic = 0
  end,
})

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
    if autocomplete == 'coc' then
      require('nvim-autopairs').setup{
        map_cr = false,
      }
    else
      require('nvim-autopairs').setup()
    end
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
      vnoremap <silent> <Leader>b y :d_ <bar> :call bible#insert_quote(substitute(@", '\n$', '', ''))<CR>
    ]])
  end,
})

-- Fuzzy finder
use({
  'nvim-telescope/telescope.nvim',
  requires = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons',
    'nvim-telescope/telescope-live-grep-args.nvim',
    { 'nvim-telescope/telescope-fzf-native.nvim', run = 'make' },
  },
  config = function()
    require('user/plugins/telescope')
  end,
})

-- File tree sidebar
use({
  'nvim-tree/nvim-tree.lua',
  requires = 'nvim-tree/nvim-web-devicons',
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

-- Merginal
use({
  'idanarye/vim-merginal'
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
    vim.keymap.set('n', '<F2>', ':FloatermToggle<CR>')
    vim.keymap.set('t', '<F2>', '<C-\\><C-n>:FloatermToggle<CR>')
    vim.keymap.set('t', '<F3>', '<C-\\><C-n>')
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

-- Neotest
-- use {
--   "nvim-neotest/neotest",
--   requires = {
--     "nvim-lua/plenary.nvim",
--     "antoinemadec/FixCursorHold.nvim",
--     "nvim-treesitter/nvim-treesitter",
--     "nvim-neotest/neotest-python"
--   },
--   config = function()
--     require('user.plugins.neotest')
--   end,
-- }

-- nvim-notify
use 'rcarriga/nvim-notify'

if autocomplete == 'coc' then
  --coc
  use ({
      'neoclide/coc.nvim', branch = 'release',
      config = function()
        require('user.plugins.coc')
      end,
    })
else
  -- nvim Lsp
  use({
    'neovim/nvim-lspconfig',
    requires = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'b0o/schemastore.nvim',
      'jose-elias-alvarez/null-ls.nvim',
      'jayp0521/mason-null-ls.nvim',
      'folke/lsp-colors.nvim',
    },
    config = function()
      require('user.plugins.lspconfig')
    end,
  })

  use({
    'L3MON4D3/LuaSnip',
    config = function()
      require('user.plugins.luasnip')
    end,
  })

  use({
    'hrsh7th/nvim-cmp',
    requires = {
      'L3MON4D3/LuaSnip',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-cmdline',
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-nvim-lsp-signature-help',
      'hrsh7th/cmp-nvim-lua',
      'hrsh7th/cmp-path',
      'onsails/lspkind-nvim',
      'saadparwaiz1/cmp_luasnip',
    },
    config = function()
      require('user.plugins.cmp')
    end,
  })

end

-- bufferline
use({
  'akinsho/bufferline.nvim',
  requires = 'nvim-tree/nvim-web-devicons',
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

-- treesitter blade parsers 추가
vim.cmd([[
  augroup BladeFiletypeRelated
    autocmd!
    autocmd BufNewFile,BufRead *.blade.php set ft=blade
  augroup END
]])

local parser_config = require "nvim-treesitter.parsers".get_parser_configs()
parser_config.blade = {
  install_info = {
    url = "https://github.com/EmranMR/tree-sitter-blade",
    files = {"src/parser.c"},
    branch = "main",
  },
  filetype = "blade"
}

-- rainbow delimiters
use({
  'HiPhish/rainbow-delimiters.nvim',
  config = function()
      local rainbow_delimiters = require 'rainbow-delimiters'
      require('rainbow-delimiters.setup').setup {
       strategy = {
            [''] = rainbow_delimiters.strategy['global'],
            vim = rainbow_delimiters.strategy['local'],
        },
        query = {
            [''] = 'rainbow-delimiters',
            lua = 'rainbow-blocks',
        },
        priority = {
            [''] = 110,
            lua = 210,
        },
        highlight = {
            'RainbowDelimiterRed',
            'RainbowDelimiterYellow',
            'RainbowDelimiterBlue',
            'RainbowDelimiterOrange',
            'RainbowDelimiterGreen',
            'RainbowDelimiterViolet',
            'RainbowDelimiterCyan',
        },
    }
  end,
})

-- Html autotag
use({
  'windwp/nvim-ts-autotag',
  config = function()
    require('nvim-ts-autotag').setup({
      opts = {
        -- Defaults
        enable_close = true, -- Auto close tags
        enable_rename = true, -- Auto rename pairs of tags
        enable_close_on_slash = false -- Auto close on trailing </
      },
      -- Also override individual filetype configs, these take priority.
      -- Empty by default, useful if one of the "opts" global settings
      -- doesn't work well in a specific filetype
      per_filetype = {
        ["php"] = {
          enable_close = false
        }
      }
    })
  end,
})

-- Lualine
use({
  'nvim-lualine/lualine.nvim',
  requires = 'nvim-tree/nvim-web-devicons',
  config = function()
    require('user.plugins.lualine')
  end,
})

-- devicons
use({
  'nvim-tree/nvim-web-devicons',
  config = function()
    require('user.plugins.nvim-web-devicons')
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

-- Live Server
use { 'wolandark/vim-live-server'}


-- Cofilot
use {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  event = "InsertEnter",
  config = function()
    require("copilot").setup({})
  end,
}

use {
  "CopilotC-Nvim/CopilotChat.nvim",
  branch = "canary",
  requires = {
    { "zbirenbaum/copilot.lua" },  -- or github/copilot.vim
    { "nvim-lua/plenary.nvim" },   -- for curl, log wrapper
  },
  run = "make tiktoken",  -- Only on MacOS or Linux
  config = function()
    require("CopilotChat").setup {
      debug = true,  -- Enable debugging
    }
  end
}

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
