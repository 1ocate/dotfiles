-- Read-only environment state for application adapters. No OS-specific side effects.
local M = {}
local supported = { macos = true, ["windows-wsl"] = true, ["windows-powershell"] = true, linux = true }
function M.selection(repo, decode, host)
  local file = io.open(repo .. "/.local/environment.json", "r")
  if not file then return nil, "No saved environment; register a choice with scripts/environment.py." end
  local content = file:read("*a")
  file:close()
  content = content:gsub("^\239\187\191", "")
  local ok, state = pcall(decode, content)
  if not ok or type(state) ~= "table" or state.approved ~= true then
    return nil, "Invalid or unapproved local environment state."
  end
  if state.schemaVersion ~= nil and state.schemaVersion ~= 1 then
    return nil, "Unsupported local environment state schema."
  end
  if type(host) ~= "string" or host == "" or type(state.host) ~= "string" or state.host:lower() ~= host:lower() then
    return nil, "Local environment selection belongs to another host."
  end
  if not supported[state.environment] then return nil, "Unsupported local environment selection." end
  return state.environment
end
return M
