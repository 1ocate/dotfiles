return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      spec = {
        {
          "<leader>sf",
          desc = "Search for the selected word within the directory",
          mode = "v",
        },
      },
    },
  },
}
