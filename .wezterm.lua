local wezterm = require 'wezterm'

-- OS Check
local homePwd = os.getenv('HOME')
local osName =''
if homePwd then
    if string.match(homePwd, "/Users") then
        osName = 'Mac'
    else
        osName = 'Linux'
    end
else
    osName = 'WSL'
end

local default_domain = ''
local wsl_domains = ''
if osName == 'WSL' then
    wsl_domains = wezterm.default_wsl_domains()
    for idx, dom in ipairs(wsl_domains) do
       dom.default_prog = {"fish", "-l"}
       dom.default_cwd = '/home/locate'
    end
    default_domain = 'WSL:Ubuntu-22.04'
else
end

local keybind = {
    -- { key = 'C', mods = 'CTRL', action = wezterm.action.CopyTo 'ClipboardAndPrimarySelection' },
    { key = 'v', mods = 'CTRL', action = wezterm.action.PasteFrom 'Clipboard' },
    { key = 'q', mods = 'CTRL', action = wezterm.action{ SendString="\x11" } },

    -- For Mac
    { key = 'C', mods = 'CMD', action = wezterm.action.CopyTo 'ClipboardAndPrimarySelection' },
    { key = 'v', mods = 'CMD', action = wezterm.action.PasteFrom 'Clipboard' },
}

local font_rules = {
    {
        italic = false,
        --bold = false,
        font = wezterm.font("MesloLGM NF"),
    },
}

local scheme = wezterm.get_builtin_color_schemes()['Matrix (terminal.sexy)']
 scheme.brights = {
     '#688061',
     '#2fc079',
     '#90d762',
     '#faff00',
     '#4f7e7e',
     '#11ff25',
     '#c1ff8a',
     '#ffffff',
 }
 scheme.ansi = {
     "#000000",
     "#454545",
     "#00cc00",
     "#00cc00",
     "#026302",
     "#55ff55",
     "#00cc00",
     "#00cc00",
 }


local color_schemes = {
-- Override the builtin Gruvbox Light scheme with our modification.
    ['locate'] = scheme,
}

local color_scheme = "locate"

wezterm.on('update-right-status', function(window, pane)
  -- "format Wed Mar 3 08:14"
  local date = wezterm.strftime '%a %b %-d %H:%M '

  -- battery info
  local bat = ''
  if osName == 'Mac' then
      for _, b in ipairs(wezterm.battery_info()) do
        bat = '🔋 ' .. string.format('%.0f%%', b.state_of_charge * 100)
      end
  end

  window:set_right_status(wezterm.format {
    { Text = bat .. '   ' .. date },
  })
end)

local setting = {}

-- only Wsl use domain
if osName == 'WSL' then
    setting['wsl_domains'] = wsl_domains
    setting['default_domain'] = default_domain
end

setting['font_rules'] = font_rules
setting['keys'] = keybind
setting['color_schemes'] = color_schemes
setting['color_scheme'] = color_scheme
setting['term'] = 'wezterm'

return setting
