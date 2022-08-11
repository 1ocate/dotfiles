local wezterm = require 'wezterm'
local wsl_domains = wezterm.default_wsl_domains()

 --for idx, dom in ipairs(wsl_domains) do
 --    dom.default_prog = { 'zsh' }
 --    dom.default_cwd = "/home/locate"
 --end

local wsl_domains = wezterm.default_wsl_domains()

-- Always use zsh in my WSL.  but really: I recommend running `chsh` inside WSL to make it the default!
for idx, dom in ipairs(wsl_domains) do
   dom.default_prog = {"zsh", "-l"}
   dom.default_cwd = "/home/locate"
end

local scheme = wezterm.get_builtin_color_schemes()['Matrix (terminal.sexy)']
scheme.brights = {
 '#688060',
    '#2fc079',
    '#90d762',
    '#faff00',
    '#4f7e7e',
    '#11ff25',
    '#c1ff8a',
    '#678c61',
}


--local act = wezterm.action
return {
    wsl_domains = wsl_domains,
    default_domain = 'WSL:Ubuntu20.04LTS',
    --default_prog = {'bash'},
    default_cwd = "/home/locate",
    font_rules = {
        {
            italic = false,
            bold = false,
            font = wezterm.font("MesloLGS NF"),
        },
    },
    keys = {
        { key = 'C', mods = 'CTRL', action = wezterm.action.Copy },
        { key = 'v', mods = 'CTRL', action = wezterm.action.Paste },

        -- For Mac
        { key = 'C', mods = 'CMD', action = wezterm.action.Copy },
        { key = 'v', mods = 'CMD', action = wezterm.action.Paste},
    },

  -- Middle mouse button pastes the clipboard.
  -- Note that this is the default so you needn't copy this.
  mouse_bindings = {
    {
      event = { Up = { streak = 1, button = 'Middle' } },
      mods = 'NONE',
      action = wezterm.action.Paste,
    },
  },    
  color_schemes = {
    -- Override the builtin Gruvbox Light scheme with our modification.
    ['test'] = scheme,
  },

  color_scheme = "test",

}
