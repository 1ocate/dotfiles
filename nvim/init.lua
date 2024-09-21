-- bootstrap lazy.nvim, LazyVim and your plugins
local homePwd = os.getenv("HOME")
local wslEnv = os.getenv("WSLENV")

osName = ""
if homePwd then
  if string.match(homePwd, "/Users") then
    osName = "Mac"
  else
    osName = "Linux"

    if wslEnv then
      osName = "WSL"
    end
  end
else
  osName = "Other"
end

autocomplete = "cmp"
visualSelectMode = true
require("config.lazy")
