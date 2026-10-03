-- Read-only selection shared by Neovim and WezTerm. Never infer user approval.
local M = {}
function M.windows_selection(repo, decode, host)
  local path = repo .. "/.local/environment.json"
  local file = io.open(path, "r")
  if not file then return nil, "No local environment selection; run setup with -ApprovePowerShell." end
  local content = file:read("*a")
  file:close()
  local ok, state = pcall(decode, content)
  if not ok or type(state) ~= "table" or state.approved ~= true then
    return nil, "Invalid local environment selection; review .local/environment.json."
  end
  if type(host) ~= "string" or host == "" or type(state.host) ~= "string"
      or state.host:lower() ~= host:lower() then
    return nil, "Local environment selection belongs to another host."
  end
  if state.environment ~= "windows-powershell" and state.environment ~= "windows-wsl" then
    return nil, "Unsupported local environment selection."
  end
  return state.environment
end
return M
