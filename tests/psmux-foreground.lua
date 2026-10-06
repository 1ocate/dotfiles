-- Foreground marker isolation and lifecycle; actual ConPTY is tested separately.
local original_vim, original_stderr = vim, io.stderr
local events, writes = {}, {}
local function run(win, approved, tmux)
  events, writes = {}, {}
  io.stderr = { write=function(_, s) writes[#writes+1]=s end, flush=function() end }
  _G.vim = {
    env={TMUX=tmux}, g={dotfiles_environment=approved and 'windows-powershell' or nil},
    fn={has=function(feature) return feature=='win32' and win and 1 or 0 end},
    api={nvim_create_augroup=function() return 1 end,
      nvim_create_autocmd=function(names, spec) for _,name in ipairs(names) do events[name]=spec.callback end end},
  }
  dofile('nvim/lua/config/psmux.lua').setup()
end
for _,case in ipairs({
  {false,false,'/tmp/tmux-100/default,1,0'},
  {false,true,'/tmp/psmux-1/dotfiles,1,0'},
  {true,false,'/tmp/psmux-1/dotfiles,1,0'},
  {true,true,'/tmp/psmux-1/other,1,0'},
  {true,true,nil},
}) do
  run(unpack(case))
  assert(#writes==0 and next(events)==nil,'Foreign/unapproved environment emitted terminal markers')
end
run(true,true,'/tmp/psmux-1/dotfiles,1,0')
assert(writes[1]=='\27]133;C;cmdline_url=nvim\7')
events.VimSuspend(); assert(writes[#writes]=='\27]133;D\7')
events.VimResume(); assert(writes[#writes]=='\27]133;C;cmdline_url=nvim\7')
events.VimLeavePre(); assert(writes[#writes]=='\27]133;D\7')
_G.vim, io.stderr = original_vim, original_stderr
print('PASS: psmux foreground lifecycle and non-target environment isolation')
