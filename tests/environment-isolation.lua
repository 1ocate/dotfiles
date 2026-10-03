-- Run with nvim --headless -u NONE -i NONE -l tests/environment-isolation.lua
-- Baseline files are supplied by DOTFILES_BASELINE (exported from main).
local root = vim.fn.getcwd()
local baseline = assert(os.getenv("DOTFILES_BASELINE"), "DOTFILES_BASELINE is required")
local real_vim, real_getenv = vim, os.getenv
local function equal(a, b, label)
  assert(real_vim.deep_equal(a, b), label .. " differs from main")
end
local scenarios = {
  { id = "macos", triple = "aarch64-apple-darwin", home = "/Users/test", os_name = "Mac" },
  { id = "linux", triple = "x86_64-unknown-linux-gnu", home = "/home/test", os_name = "Linux" },
  { id = "windows-wsl", triple = "x86_64-unknown-linux-gnu", home = "/home/test", os_name = "WSL" },
  { id = "windows-powershell", triple = "x86_64-pc-windows-msvc", os_name = "Windows" },
}
local function nvim_config(directory, scenario)
  local opts, events, commands = {}, {}, {}
  opts.backupdir = { remove = function() end }
  opts.fillchars = { append = function() end }
  _G.vim = {
    opt = opts, g = {}, v = {},
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
    target_triple = scenario.triple,
    action = setmetatable({ CopyTo = function(x) return { copy = x } end,
      PasteFrom = function(x) return { paste = x } end }, { __call = function(_, x) return x end }),
    font_with_fallback = function(x) return x end,
    get_builtin_color_schemes = function() return { ["Matrix (terminal.sexy)"] = {} } end,
    on = function() end,
    run_child_process = function()
      calls = calls + 1
      assert(scenario.id == "windows-powershell", "Unix launched Windows command")
      return true, "C:/PowerShell/pwsh.exe\r\n"
    end,
    default_wsl_domains = function() error("Implicit WSL domain setup") end,
  }
  return dofile(directory .. "/.wezterm.lua"), calls
end
for _, scenario in ipairs(scenarios) do
  os.getenv = function(name)
    if name == "HOME" then return scenario.home end
    if name == "WSLENV" then return scenario.id == "windows-wsl" and "" or nil end
    return real_getenv(name)
  end
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
  end
  print("PASS: " .. scenario.id)
end
_G.vim, os.getenv = real_vim, real_getenv
print("Baseline comparison complete; no plugins, shell commands or host settings were modified.")
