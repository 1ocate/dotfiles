-- bootstrap lazy.nvim, LazyVim and your plugins
osName = ""
if vim.fn.has("win32") == 1 then
  -- Legacy osName describes the platform, not the approved shell environment.
  osName = "Windows"
  local source = debug.getinfo(1, "S").source:sub(2)
  source = (vim.uv.fs_realpath(source) or source):gsub("\\", "/")
  local repo = source:match("^(.*)/nvim/init%.lua$") or "."
  local selected, reason = dofile(repo .. "/environment.lua").windows_selection(
    repo, vim.json.decode, os.getenv("COMPUTERNAME"))
  vim.g.dotfiles_environment = selected or "windows-unconfigured"
  if reason then
    vim.schedule(function() vim.notify(reason, vim.log.levels.WARN) end)
  end
elseif vim.fn.has("macunix") == 1 then
  osName = "Mac"
  vim.g.dotfiles_environment = "macos"
elseif vim.fn.has("wsl") == 1 then
  osName = "WSL"
  vim.g.dotfiles_environment = "windows-wsl"
else
  osName = "Linux"
  vim.g.dotfiles_environment = "linux"
end

autocomplete = "cmp"
visualSelectMode = true
require("config.lazy")
