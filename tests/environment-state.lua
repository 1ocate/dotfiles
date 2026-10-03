-- nvim --headless -u NONE -i NONE -l tests/environment-state.lua
local state = dofile("environment.lua")
local original = io.open
local payload
io.open = function()
  if not payload then return nil end
  return { read = function() return payload end, close = function() end }
end
for _, id in ipairs({ "macos", "windows-wsl", "windows-powershell", "linux" }) do
  payload = vim.json.encode({ schemaVersion = 1, environment = id, host = "fixture", approved = true })
  assert(state.selection("fixture-repo", vim.json.decode, "FIXTURE") == id)
  assert(state.selection("fixture-repo", vim.json.decode, "other-host") == nil)
end
for _, invalid in ipairs({ "garbled", '[]', '{"approved":"true"}', '{"approved":true,"environment":"windows","host":"fixture"}', '{"schemaVersion":2,"approved":true,"environment":"linux","host":"fixture"}' }) do
  payload = invalid
  assert(state.selection("fixture-repo", vim.json.decode, "fixture") == nil)
end
payload = nil
assert(state.selection("fixture-repo", vim.json.decode, "fixture") == nil)
io.open = original
print("PASS: four environment IDs, host mismatch, missing/invalid/unsupported state; read-only Lua reader.")
