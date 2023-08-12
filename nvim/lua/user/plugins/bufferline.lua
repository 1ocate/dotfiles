require('bufferline').setup({
  options = {
    indicator = {
      icon = ' ',
    },
    show_close_icon = false,
    tab_size = 0,
    max_name_length = 25,
    offsets = {
      {
        filetype = 'NvimTree',
        text = '  Files',
        highlight = 'StatusLine',
        text_align = 'left',
      },
    },
    separator_style = 'slant',
    modified_icon = '',
    custom_areas = {
      left = function()
        return {
          { text = '    ', fg = '#8fff6d' },
        }
      end,
    },
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
      fg = '#ffffff'

   },
   buffer_visible = {
      bg = { attribute = 'bg', highlight = 'normal' },
   },
   buffer_selected = {
       -- bg = '#999999',
       -- fg = { attribute = 'fg', highlight = 'StatusLine' },
       fg = '#ffffff',
       bold = true,
       italic = true,
   },
    modified = {
       fg = { attribute = 'fg', highlight = 'GruvboxRed' },
   },
   modified_visible = {
      fg = { attribute = 'fg', highlight = 'GruvboxRed' },
   },
   modified_selected = {
     fg = { attribute = 'fg', highlight = 'GruvboxRed' },
   },
   -- duplicate = {
   --   fg = { attribute = 'fg', highlight = 'GruvboxYellow' },
   -- },
   duplicate_visible = {
     fg = { attribute = 'fg', highlight = 'GruvboxGreen' },
   },
   duplicate_selected= {
     fg = { attribute = 'fg', highlight = 'GruvboxGreen' },
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
})
