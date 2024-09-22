-- local separator = {
--   '"▏"',
--   color = "StatusLineNonText",
-- }

return {
  {
    "nvim-lualine/lualine.nvim",
    opts = {
      component_separators = { left = "", right = "" },
      options = {
        section_separators = { left = "", right = "" },
        globalstatus = false,
        theme = "auto",
      },
      sections = {
        lualine_a = {
          "mode",
          -- separator,
        },
        lualine_b = {
          "branch",
          "diff",
          -- separator,
          -- '"🖧  " .. tostring(#vim.tbl_keys(vim.lsp.buf_get_clients()))',
          -- { 'diagnostics', sources = { 'nvim_diagnostic' } },
          -- separator,
        },
        lualine_c = {
          "filename",
        },
        lualine_x = {
          "filetype",
          "encoding",
          "fileformat",
        },
        lualine_y = {
          -- separator,
          '(vim.bo.expandtab and "SP" or "Tab") .. " " .. vim.bo.shiftwidth',
          -- separator,
        },
        lualine_z = {
          "location",
          "progress",
        },
      },
    },
  },
}
