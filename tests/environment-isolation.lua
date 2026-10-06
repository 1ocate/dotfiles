-- Run with nvim --headless -u NONE -i NONE -l tests/environment-isolation.lua
-- Baseline files are supplied by DOTFILES_BASELINE (exported from main).
local root = vim.fn.getcwd()
local baseline = assert(os.getenv("DOTFILES_BASELINE"), "DOTFILES_BASELINE is required")
local real_vim, real_getenv, real_open = vim, os.getenv, io.open
local function equal(a, b, label)
  assert(real_vim.deep_equal(a, b), label .. " differs from main")
end
local scenarios = {
  { id = "macos", triple = "aarch64-apple-darwin", home = "/Users/test", os_name = "Mac" },
  { id = "linux", triple = "x86_64-unknown-linux-gnu", home = "/home/test", os_name = "Linux" },
  { id = "windows-wsl", triple = "x86_64-unknown-linux-gnu", home = "/home/test", os_name = "WSL" },
  { id = "windows-powershell", triple = "x86_64-pc-windows-msvc", os_name = "Windows", choice = "windows-powershell" },
}
local function nvim_config(directory, scenario)
  local opts, events, commands = {}, {}, {}
  opts.backupdir = { remove = function() end }
  opts.fillchars = { append = function() end }
  _G.vim = {
    opt = opts, g = {}, v = {},
    uv = real_vim.uv, json = real_vim.json,
    schedule = function() end, notify = function() end, log = real_vim.log,
    cmd = function(command) commands[#commands + 1] = command end,
    fn = {
      has = function(feature)
        return ((feature == "win32" and scenario.id == "windows-powershell")
          or (feature == "macunix" and scenario.id == "macos")
          or (feature == "wsl" and scenario.id == "windows-wsl")) and 1 or 0
      end,
      executable = function() return 1 end,
      system = function() error("Unexpected external shell command") end,
    },
    keymap = { set = function() end },
    api = {
      nvim_create_augroup = function() return 1 end,
      nvim_create_autocmd = function(event, spec) events[event] = spec end,
    },
  }
  package.loaded["config.lazy"] = true -- Never bootstrap/download plugins in this test.
  dofile(directory .. "/nvim/init.lua")
  dofile(directory .. "/nvim/lua/config/options.lua")
  local copilot = dofile(directory .. "/nvim/lua/plugins/CopilotChat.lua")
  dofile(directory .. "/nvim/lua/plugins/yankclip.lua").config()
  opts.backupdir, opts.fillchars = nil, nil
  return { options = opts, commands = commands, build = copilot[1].build,
    clipboard_event = events.TextYankPost ~= nil, os_name = osName }
end
local function wezterm_config(directory, scenario)
  local calls = 0
  package.loaded.wezterm = {
    GLOBAL = {},
    config_dir = directory,
    target_triple = scenario.triple,
    action = setmetatable({ CopyTo = function(x) return { copy = x } end,
      PasteFrom = function(x) return { paste = x } end }, { __call = function(_, x) return x end }),
    font_with_fallback = function(x) return x end,
    get_builtin_color_schemes = function() return { ["Matrix (terminal.sexy)"] = {} } end,
    on = function() end,
    json_parse = real_vim.json.decode,
    add_to_config_reload_watch_list = function() end,
    log_warn = function() end,
    run_child_process = function()
      calls = calls + 1
      assert(scenario.id == "windows-powershell", "Unix launched Windows command")
      return true, "C:/PowerShell/pwsh.exe\r\n"
    end,
    default_wsl_domains = function()
      assert(scenario.choice == "windows-wsl", "Implicit WSL domain setup")
      return { { name = "WSL:fixture" } }
    end,
  }
  local original_debug = debug
  debug = nil -- WezTerm omits Lua's debug library.
  local ok, result = pcall(dofile, directory .. "/.wezterm.lua")
  debug = original_debug
  assert(ok, result)
  return result, calls
end
local function select_scenario(scenario)
  os.getenv = function(name)
    if name == "COMPUTERNAME" then return "fixture-host" end
    if name == "HOME" then return scenario.home end
    if name == "WSLENV" then return scenario.id == "windows-wsl" and "" or nil end
    return real_getenv(name)
  end
  io.open = function(path, mode)
    if path:match("/%.local/environment%.json$") then
      assert(scenario.id == "windows-powershell", "Unix read Windows selection")
      if not scenario.choice then return nil end
      local content = scenario.corrupt and "invalid-json" or real_vim.json.encode({
        environment = scenario.choice, host = scenario.host or "fixture-host", approved = true,
      })
      return { read = function() return content end, close = function() end }
    end
    if path:match('/%.local/psmux%.json$') then
      assert(scenario.id == 'windows-powershell' and scenario.choice == 'windows-powershell',
        'psmux state was read outside the approved PowerShell branch')
      if not scenario.mux then return nil end
      local content = scenario.mux_corrupt and 'invalid-json' or real_vim.json.encode(scenario.mux)
      return { read = function() return content end, close = function() end }
    end
    if path:match('/Programs/psmux/3%.3%.8/psmux%.exe$') then
      assert(scenario.id == 'windows-powershell', 'Unix checked a Windows executable')
      return scenario.binary and { close = function() end } or nil
    end
    return real_open(path, mode)
  end
end
for _, scenario in ipairs(scenarios) do
  select_scenario(scenario)
  local actual = nvim_config(root, scenario)
  assert(actual.os_name == scenario.os_name, "Wrong OS: " .. scenario.id)
  local terminal, calls = wezterm_config(root, scenario)
  if scenario.id ~= "windows-powershell" then
    equal(actual, nvim_config(baseline, scenario), scenario.id .. " Neovim")
    equal(terminal, wezterm_config(baseline, scenario), scenario.id .. " WezTerm")
    assert(calls == 0)
  else
    assert(actual.options.shell == "pwsh" and actual.build == nil and actual.clipboard_event)
    assert(terminal.default_domain == "local" and #terminal.wsl_domains == 0 and calls == 1)
    assert(terminal.term == "xterm-256color", "Windows Git pager TERM compatibility missing")
  end
  print("PASS: " .. scenario.id)
end
for _, choice in ipairs({
  { label = "missing" },
  { label = "WSL", choice = "windows-wsl" },
  { label = "macOS on native Windows", choice = "macos" },
  { label = "other host", choice = "windows-powershell", host = "other-host" },
  { label = "invalid JSON", choice = "windows-powershell", corrupt = true },
}) do
  choice.id, choice.triple = "windows-powershell", "x86_64-pc-windows-msvc"
  select_scenario(choice)
  local native = nvim_config(root, choice)
  local terminal, calls = wezterm_config(root, choice)
  assert(native.options.shell == nil and not native.clipboard_event)
  assert(terminal.default_prog == nil and calls == 0)
  if choice.choice == "windows-wsl" then
    assert(terminal.default_domain == "WSL:fixture")
    assert(terminal.wsl_domains[1].default_prog[1] == "fish")
  else
    assert(terminal.default_domain == nil)
  end
  print("PASS: " .. choice.label .. " selection does not force PowerShell")
end
for _, feature in ipairs({
  { label = 'enabled', enabled = true, binary = true, expect = true },
  { label = 'disabled', enabled = false, binary = true },
  { label = 'wrong host', enabled = true, host = 'other-host', binary = true },
  { label = 'missing binary', enabled = true },
  { label = 'string enabled', enabled = 'true', binary = true },
  { label = 'invalid feature JSON', enabled = true, binary = true, corrupt = true },
  { label = 'unknown schema', enabled = true, binary = true, schema = 9 },
}) do
  local scenario = { id = 'windows-powershell', triple = 'x86_64-pc-windows-msvc',
    choice = 'windows-powershell', binary = feature.binary, mux_corrupt = feature.corrupt,
    mux = { schemaVersion = feature.schema or 1, host = feature.host or 'fixture-host',
      enabled = feature.enabled, version = '3.3.8' } }
  select_scenario(scenario)
  local terminal = wezterm_config(root, scenario)
  local launched = terminal.default_prog[4] == '-File'
  assert(launched == (feature.expect == true), feature.label .. ' startup differs')
  local ctrl_h, ctrl_l
  for _, key in ipairs(terminal.keys) do
    if key.key == 'h' and key.mods == 'CTRL' then ctrl_h = key.action end
    if key.key == 'l' and key.mods == 'CTRL' then ctrl_l = key.action end
  end
  assert((ctrl_h ~= nil) == launched, feature.label .. ' Ctrl+h opt-in differs')
  if ctrl_h then assert(ctrl_h.SendString == '\x1bh', 'Wrong Ctrl+h encoding') end
  assert((ctrl_l ~= nil) == launched, feature.label .. ' Ctrl+l opt-in differs')
  if ctrl_l then assert(ctrl_l.SendString == '\x0c', 'Wrong Ctrl+l encoding') end
  print('PASS: psmux ' .. feature.label .. ' startup')
end
_G.vim, os.getenv, io.open = real_vim, real_getenv, real_open
print("Baseline comparison complete; no plugins, shell commands or host settings were modified.")
