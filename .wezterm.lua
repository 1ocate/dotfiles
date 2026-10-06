local wezterm = require 'wezterm'

-- OS detection is separate from the user's saved environment selection.
local is_windows = wezterm.target_triple:find('windows', 1, true) ~= nil
local is_macos = wezterm.target_triple:find('apple', 1, true) ~= nil
local selected_environment
local windows_repo
if is_windows then
    -- WezTerm's Lua runtime does not expose the debug library.
    -- The loader supplies its checkout; direct loading uses the config directory.
    local repo = (wezterm.GLOBAL.dotfiles_repo or wezterm.config_dir):gsub('\\', '/')
    if repo == '' then repo = '.' end -- Relative --config-file in the checkout.
    windows_repo = repo
    local state_path = repo .. '/.local/environment.json'
    wezterm.add_to_config_reload_watch_list(state_path)
    local reason
    selected_environment, reason = dofile(repo .. '/environment.lua').selection(
        repo, wezterm.json_parse, os.getenv('COMPUTERNAME'))
    if selected_environment and selected_environment ~= 'windows-powershell' and selected_environment ~= 'windows-wsl' then
        selected_environment, reason = nil, 'Saved environment does not match a native Windows process.'
    end
    if reason then wezterm.log_warn(reason) end
end

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

if selected_environment == 'windows-powershell' then
    -- Prefer PowerShell 7 when available, otherwise use Windows PowerShell 5.1.
    local found_pwsh, pwsh_path = wezterm.run_child_process { 'where.exe', 'pwsh.exe' }
    local executable_path = found_pwsh and pwsh_path:match('[^\r\n]+')
    if executable_path then
        setting['default_prog'] = { executable_path, '-NoLogo' }
    else
        setting['default_prog'] = { 'powershell.exe', '-NoLogo' }
    end
    -- Host-local opt-in; missing tools retain the plain PowerShell startup.
    local mux_state_path = windows_repo .. '/.local/psmux.json'
    wezterm.add_to_config_reload_watch_list(mux_state_path)
    local mux_file = io.open(mux_state_path, 'r')
    if mux_file then
        local content = mux_file:read('*a'):gsub('^\239\187\191', '')
        mux_file:close()
        local ok, feature = pcall(wezterm.json_parse, content)
        if ok and type(feature) == 'table' and feature.schemaVersion == 1
            and feature.enabled == true and type(feature.host) == 'string'
            and feature.host:lower() == (os.getenv('COMPUTERNAME') or ''):lower() then
            local mux_bin = (os.getenv('LOCALAPPDATA') or '') .. '/Programs/psmux/3.3.8/psmux.exe'
            local binary = io.open(mux_bin, 'rb')
            if binary and executable_path then
                binary:close()
                setting['default_prog'] = { executable_path, '-NoLogo', '-NoProfile',
                    '-File', windows_repo .. '/scripts/start-psmux.ps1' }
            elseif binary then
                binary:close()
            end
        end
    end
    setting['default_domain'] = 'local'
    setting['wsl_domains'] = {}
    -- Preserve the existing default font selection on Unix hosts.
    setting['font'] = wezterm.font_with_fallback(fonts)
end

-- Preserve WSL startup only for an explicitly selected WSL host.
if selected_environment == 'windows-wsl' then
    local domains = wezterm.default_wsl_domains()
    for _, domain in ipairs(domains) do
        domain.default_prog = { 'fish', '-l' }
    end
    setting['wsl_domains'] = domains
    if domains[1] then setting['default_domain'] = domains[1].name end
end

setting['font_rules'] = font_rules
setting['keys'] = keybind
setting['color_schemes'] = color_schemes
setting['color_scheme'] = color_scheme
-- Use a terminal entry recognized by Git for Windows' pager.
setting['term'] = selected_environment == 'windows-powershell' and 'xterm-256color' or 'wezterm'

return setting
