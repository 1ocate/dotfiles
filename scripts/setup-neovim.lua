-- Native Windows bootstrap, called after restoring the existing plugin lock.
if vim.fn.has("win32") ~= 1 then
  error("This setup entry point is for native Windows only")
end
if vim.g.dotfiles_environment ~= "windows-powershell" then
  error("Approved windows-powershell selection is required before installing Neovim tools")
end
local function setup()
  require("lazy").load({ plugins = { "nvim-treesitter", "mason.nvim" } })
  local treesitter = require("nvim-treesitter")
  local plugin = require("lazy.core.config").plugins["nvim-treesitter"]
  local options = require("lazy.core.plugin").values(plugin, "opts", false)
  treesitter.install(options.ensure_installed or {}):wait(300000)

  -- Opening a normal buffer triggers the same LazyFile initialization as the GUI.
  vim.cmd.edit(vim.fn.stdpath("config") .. "/init.lua")
  local registry = require("mason-registry")
  registry.refresh(function()
    local mason = require("lazy.core.config").plugins["mason.nvim"]
    local mason_opts = require("lazy.core.plugin").values(mason, "opts", false)
    local packages = {}
    for _, name in ipairs(mason_opts.ensure_installed or {}) do
      local package = registry.get_package(name)
      packages[#packages + 1] = package
      if not package:is_installed() and not package:is_installing() then
        package:install()
      end
    end
    local done = vim.wait(300000, function()
      for _, package in ipairs(packages) do
        if package:is_installing() then
          return false
        end
      end
      return true
    end, 200)
    local missing = {}
    for _, package in ipairs(packages) do
      if not package:is_installed() then
        missing[#missing + 1] = package.name
      end
    end
    if not done or #missing > 0 then
      vim.api.nvim_err_writeln("Mason packages incomplete: " .. table.concat(missing, ", "))
      vim.cmd("cquit 1")
      return
    end
    local parser_failed = {}
    for _, language in ipairs(options.ensure_installed or {}) do
      if not pcall(vim.treesitter.language.add, language) then
        parser_failed[#parser_failed + 1] = language
      end
    end
    if #parser_failed > 0 then
      vim.api.nvim_err_writeln("Parsers incomplete: " .. table.concat(parser_failed, ", "))
      vim.cmd("cquit 1")
      return
    end
    print("Neovim plugin, parser and tool setup complete.")
    vim.cmd("qa!")
  end)
end

vim.schedule(function()
  local ok, err = pcall(setup)
  if not ok then
    vim.api.nvim_err_writeln(tostring(err))
    vim.cmd("cquit 1")
  end
end)
