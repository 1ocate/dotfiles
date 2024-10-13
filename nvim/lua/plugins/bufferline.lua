return {
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        indicator = {
          icon = " ",
        },
        show_close_icon = false,
        tab_size = 0,
        max_name_length = 25,
        offsets = {
          {
            filetype = "neo-tree",
            text = "  Files",
            highlight = "Directory",
            text_align = "left",
          },
        },
        separator_style = "slant",
        modified_icon = "",
        custom_areas = {
          left = function()
            return {
              { text = "    ", fg = "#8fff6d" },
            }
          end,
        },
        custom_filter = function(bufnr)
          -- This is the recommended code in the bufferline document
          local exclude_ft = { "fugitive" }
          local cur_ft = vim.bo[bufnr].filetype
          local should_show = not vim.tbl_contains(exclude_ft, cur_ft)

          -- This is my custom code
          if vim.g.show_file_buffer_only then
            should_show = should_show and vim.fn.bufname(buffnr) ~= ""
          end

          return should_show
        end,
        -- 버퍼가 1개일때도 표시
        always_show_bufferline = true,
      },
      highlights = {
        -- fill = {
        --    bg = { attribute = 'bg', highlight = 'Normal' },
        --  },
        -- background = {
        --   bg = { attribute = 'bg', highlight = 'StatusLine' },
        -- },
        --   tab = {
        --     bg = { attribute = 'bg', highlight = 'StatusLine' },
        --   tab_close = {
        --   },
        --     bg = { attribute = 'bg', highlight = 'StatusLine' },
        --   },
        --   close_button = {
        --     bg = { attribute = 'bg', highlight = 'Tabline' },
        --     fg = { attribute = 'fg', highlight = 'TabLine' },
        --   },
        -- close_button_visible = {
        --    bg = '#ffffff',
        --    fg = '#000000',
        --    -- bg = { attribute = 'bg', highlight = 'Tabline' },
        --    -- fg = { attribute = 'fg', highlight = 'StatusLineNonText' },
        -- },
        close_button_selected = {
          -- bg = { attribute = 'bg', highlight = 'StatusLine' },
          -- fg = { attribute = 'fg', highlight = 'StatusLine' },
          fg = "#ffffff",
        },
        buffer_visible = {
          bg = { attribute = "bg", highlight = "normal" },
        },
        buffer_selected = {
          -- bg = '#999999',
          -- fg = { attribute = 'fg', highlight = 'StatusLine' },
          fg = "#ffffff",
          bold = true,
          italic = true,
        },
        modified = {
          fg = { attribute = "fg", highlight = "GruvboxRed" },
        },
        modified_visible = {
          fg = { attribute = "fg", highlight = "GruvboxRed" },
        },
        modified_selected = {
          fg = { attribute = "fg", highlight = "GruvboxRed" },
        },
        -- duplicate = {
        --   fg = { attribute = 'fg', highlight = 'GruvboxYellow' },
        -- },
        duplicate_visible = {
          fg = { attribute = "fg", highlight = "GruvboxGreen" },
        },
        duplicate_selected = {
          fg = { attribute = "fg", highlight = "GruvboxGreen" },
        },
        --    separator = {
        --       fg = { attribute = 'bg', highlight = 'Tabline' },
        --       bg = { attribute = 'bg', highlight = 'Tabline' },
        --    },
        -- separator_selected = {
        --    bg = { attribute = 'bg', highlight = 'StatusLine' },
        --    fg = '#000000',
        -- },
        --    separator_visible = {
        --      fg = { attribute = 'bg', highlight = 'Tabline' },
        --      bg = { attribute = 'bg', highlight = 'Tabline' },
        --    },
      },
    },
  },
}
