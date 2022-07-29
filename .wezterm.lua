local wezterm = require 'wezterm'
local wsl_domains = wezterm.default_wsl_domains()

for idx, dom in ipairs(wsl_domains) do
    dom.default_prog = { 'zsh', '-1' }
    dom.default_cwd = "/home/locate"
end

local act = wezterm.action
return {
    wsl_domains = wsl_domains,
    default_domain = 'WSL:Ubuntu20.04LTS',
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
  color_scheme = "SeaShells"


}
