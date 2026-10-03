-- bootstrap lazy.nvim, LazyVim and your plugins
osName = ""
if vim.fn.has("win32") == 1 then
  osName = "Windows"
elseif vim.fn.has("macunix") == 1 then
  osName = "Mac"
elseif vim.fn.has("wsl") == 1 then
  osName = "WSL"
else
  osName = "Linux"
end

autocomplete = "cmp"
visualSelectMode = true
require("config.lazy")
