return {
  "nvim-telescope/telescope.nvim",
  keys = {
    { "<leader>sw", LazyVim.pick("grep_string"), mode = "v", desc = "Selection (Root Dir)" },
    { "<leader>sW", LazyVim.pick("grep_string", { root = false }), mode = "v", desc = "Selection (cwd)" },
    {
      "<leader>fa",
      LazyVim.pick("find_files", { no_ignore = true, prompt_title = "Find Files All" }),
      desc = "All Files (Including .gitignore)",
    },
  },
  opts = function()
    local actions = require("telescope.actions")
    return {
      defaults = {
        path_display = { truncate = 1 },
        prompt_prefix = "   ",
        selection_caret = " ",
        layout_config = {
          prompt_position = "top",
        },
        mappings = {
          -- sorting_strategy = "ascending",
          i = {
            ["<esc>"] = actions.close,
            ["<C-J>"] = actions.move_selection_next,
            ["<C-K>"] = actions.move_selection_previous,
            ["<C-Down>"] = actions.cycle_history_next,
            ["<C-Up>"] = actions.cycle_history_prev,
          },
        },
        file_ignore_patterns = { ".git/" },
      },
      pickers = {
        find_files = {
          hidden = true,
        },
        buffers = {
          previewer = false,
          layout_config = {
            width = 80,
          },
        },
        oldfiles = {
          prompt_title = "History",
        },
        lsp_references = {
          previewer = false,
        },
      },
    }
  end,
}
