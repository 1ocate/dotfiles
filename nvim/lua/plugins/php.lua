return {
  {
    -- Plugin for code formatting
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        php = { "intelephense" }, -- Use intelephense for PHP formatting
      },
    },
  },
  {
    -- Plugin for linting
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        php = { "php" }, -- Use intelephense for PHP linting
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "php" } },
  },
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "phpcs",
        "php-cs-fixer",
      },
    },
  },
}
