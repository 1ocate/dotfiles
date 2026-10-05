-- Test the Enter mapping branches without downloading/loading completion sources.
local original_cmp, original_lazyvim = package.loaded.cmp, LazyVim
local visible, active, confirmed, closed, fallback_count = false, false, 0, 0, 0
package.loaded.cmp = {
  mapping = setmetatable({}, { __call = function(_, callback) return callback end }),
  visible = function() return visible end,
  get_active_entry = function() return active and {} or nil end,
  close = function() closed = closed + 1 end,
  config = { sources = function(sources) return sources end },
}
LazyVim = { cmp = { confirm = function()
  return function() confirmed = confirmed + 1 end
end } }
local spec = dofile("nvim/lua/plugins/cmp.lua")[1]
local opts = { formatting = { format = function(_, item) return item end } }
spec.opts(nil, opts)
local enter = opts.mapping["<CR>"]
local fallback = function() fallback_count = fallback_count + 1 end
enter(fallback)
assert(fallback_count == 1 and confirmed == 0)
visible = true
enter(fallback)
assert(fallback_count == 2 and closed == 1)
active = true
enter(fallback)
assert(confirmed == 1 and fallback_count == 2, "Selected completion was not confirmed")
local bare_opts = {}
spec.opts(nil, bare_opts)
local item = bare_opts.formatting.format({ source = { name = "buffer" } }, { abbr = "test" })
assert(item.abbr == "test" and item.menu == "[Buf]")
package.loaded.cmp, LazyVim = original_cmp, original_lazyvim
print("PASS: Enter fallback, empty selection and active completion confirmation")
