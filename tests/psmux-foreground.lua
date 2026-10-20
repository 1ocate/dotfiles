-- Foreground marker isolation and lifecycle; actual ConPTY is tested separately.
local original_vim, original_stderr = vim, io.stderr
local events, writes = {}, {}
local root = original_vim.fn.getcwd()
local config = root .. '/tmux/psmux.conf'
local default_tmux = '/tmp/psmux-1/default,1,0'
local function run(win, approved, tmux, mode, markers)
  events, writes = {}, {}
  io.stderr = { write=function(_, s) writes[#writes+1]=s end, flush=function() end }
  _G.vim = {
    env={TMUX=tmux, PSMUX_SESSION=markers and markers.session or 'probe',
      PSMUX_CONFIG_FILE=markers and markers.config or config, DOTFILES_ROOT=markers and markers.root or root}, g={dotfiles_environment=approved and 'windows-powershell' or nil},
    fn={has=function(feature) return feature=='win32' and win and 1 or 0 end,
      fnamemodify=function(path, modifier) return original_vim.api.nvim_call_function("fnamemodify", {path, modifier}) end},
    api={nvim_get_mode=function() return {mode=mode or 'n'} end, nvim_create_augroup=function() return 1 end,
      nvim_create_autocmd=function(names, spec) if type(names)=='string' then names={names} end; for _,name in ipairs(names) do events[name]=spec.callback end end},
  }
  dofile('nvim/lua/config/psmux.lua').setup()
end
for _,case in ipairs({
  {false,false,'/tmp/tmux-100/default,1,0'},
  {false,true,default_tmux}, {true,false,default_tmux},
  {true,true,'/tmp/psmux-1/dotfiles,1,0'},
  {true,true,'/tmp/psmux-1/other,1,0'}, {true,true,nil},
  {true,true,default_tmux,nil,{session=''}},
  {true,true,default_tmux,nil,{config=''}},
  {true,true,default_tmux,nil,{root=''}},
  {true,true,default_tmux,nil,{config=root..'/other/psmux.conf'}},
  {true,true,default_tmux,nil,{config='tmux/psmux.conf'}},
  {true,true,default_tmux,nil,{root='.'}},
}) do
  run(unpack(case))
  assert(#writes==0 and next(events)==nil,'Foreign/unapproved environment emitted terminal markers')
end
run(true,true,default_tmux,nil,{config=config:upper():gsub('/', '\\'),root=root:gsub('\\','/')})
assert(#writes==1,'Equivalent Windows config path did not activate')
run(true,true,default_tmux)
assert(writes[1]=='\27]133;C;cmdline_url=nvim\7')
events.InsertEnter(); assert(writes[#writes]=='\27]133;C;cmdline_url=nvim-insert\7')
events.InsertLeave(); assert(writes[#writes]=='\27]133;C;cmdline_url=nvim\7')
events.VimSuspend(); assert(writes[#writes]=='\27]133;D\7')
events.VimResume(); assert(writes[#writes]=='\27]133;C;cmdline_url=nvim\7')
events.VimLeavePre(); assert(writes[#writes]=='\27]133;D\7')
run(true,true,default_tmux,'i')
assert(writes[1]=='\27]133;C;cmdline_url=nvim-insert\7','Late setup lost insert mode')
events.VimResume(); assert(writes[#writes]=='\27]133;C;cmdline_url=nvim-insert\7')
for _,mode in ipairs({'n','t','c','v'}) do
  run(true,true,default_tmux,mode)
  assert(writes[1]=='\27]133;C;cmdline_url=nvim\7','Non-insert mode received insert marker')
end
_G.vim, io.stderr = original_vim, original_stderr
print('PASS: psmux foreground lifecycle and non-target environment isolation')
