local wezterm = require 'wezterm'

-- Detect the OS independently of HOME; Windows uses a native PowerShell shell.
local is_windows = wezterm.target_triple:find('windows', 1, true) ~= nil
local is_macos = wezterm.target_triple:find('apple', 1, true) ~= nil

local keybind = {
    -- { key = 'C', mods = 'CTRL', action = wezterm.action.CopyTo 'ClipboardAndPrimarySelection' },
    { key = 'v', mods = 'CTRL', action = wezterm.action.PasteFrom 'Clipboard' },
    { key = 'q', mods = 'CTRL', action = wezterm.action{ SendString="\x11" } },

    -- For Mac
    { key = 'C', mods = 'CMD', action = wezterm.action.CopyTo 'ClipboardAndPrimarySelection' },
    { key = 'v', mods = 'CMD', action = wezterm.action.PasteFrom 'Clipboard' },
}

local fonts = {
    'MesloLGMDZ Nerd Font',
    'D2Coding',
}

local font_rules = {
    {
        italic = false,
        --bold = false,
        font = wezterm.font_with_fallback(fonts)
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
  if is_macos then
      for _, b in ipairs(wezterm.battery_info()) do
        bat = '🔋 ' .. string.format('%.0f%%', b.state_of_charge * 100)
      end
  end

  window:set_right_status(wezterm.format {
    { Text = bat .. '   ' .. date },
  })
end)

local setting = {}

if is_windows then
    -- Prefer PowerShell 7 when available, otherwise use Windows PowerShell 5.1.
    local found_pwsh, pwsh_path = wezterm.run_child_process { 'where.exe', 'pwsh.exe' }
    local executable_path = found_pwsh and pwsh_path:match('[^\r\n]+')
    if executable_path then
        setting['default_prog'] = { executable_path, '-NoLogo' }
    else
        setting['default_prog'] = { 'powershell.exe', '-NoLogo' }
    end
    setting['default_domain'] = 'local'
    setting['wsl_domains'] = {}
    -- Preserve the existing default font selection on Unix hosts.
    setting['font'] = wezterm.font_with_fallback(fonts)
end

setting['font_rules'] = font_rules
setting['keys'] = keybind
setting['color_schemes'] = color_schemes
setting['color_scheme'] = color_scheme
setting['term'] = 'wezterm'

return setting
