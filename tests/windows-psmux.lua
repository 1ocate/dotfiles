-- Headless navigator integration inside a real psmux ConPTY; no plugin downloads.
local root=assert(vim.env.DOTFILES_PSMUX_ROOT)
local mux=assert(vim.env.DOTFILES_PSMUX_EXE)
local report={version='3.3.8', tmux=vim.env.TMUX, pane=vim.env.TMUX_PANE, tests={}}
local function command(args)
  local cmd={mux}; vim.list_extend(cmd,args)
  local out=vim.fn.system(cmd)
  assert(vim.v.shell_error==0, table.concat(cmd,' ')..': '..out)
  return vim.trim(out)
end
local function active() return command({'display-message','-p','#{pane_id}'}) end
local function test(name,fn)
  local ok,err=pcall(fn); report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(err) or nil}
end
vim.schedule(function()
 local ok,err=pcall(function()
  assert(vim.env.TMUX and vim.env.TMUX_PANE,'TMUX environment missing')
  if vim.env.DOTFILES_PSMUX_FULL == '1' then
    require('lazy').load({plugins={'nvim-tmux-navigation'}})
  else
    vim.g.dotfiles_environment='windows-powershell'
    dofile(root..'/nvim/lua/config/options.lua')
    vim.opt.rtp:prepend(root..'/nvim')
    vim.opt.rtp:prepend(vim.env.LOCALAPPDATA..'/nvim-data/lazy/nvim-tmux-navigation')
    dofile(root..'/nvim/lua/plugins/vim-tmux-navigator.lua').config()
  end
  local original=vim.env.TMUX_PANE
  local wait=assert(vim.env.DOTFILES_PSMUX_WAIT)
  for i=1,3 do command({'split-window', i==2 and '-v' or '-h','-d','-t',original,'--','pwsh','-NoProfile','-File',wait}) end
  command({'select-layout','tiled'})
  test('real pane TMUX detection',function() assert(active()==original,active()) end)
  test('Neovim internal split stays inside Neovim',function()
    command({'select-pane','-t',original}); vim.cmd('vsplit'); local win=vim.api.nvim_get_current_win()
    require('nvim-tmux-navigation').NvimTmuxNavigateLeft()
    assert(vim.api.nvim_get_current_win()~=win,'internal split did not move')
    assert(active()==original,'unexpected external move'); vim.cmd('only')
  end)
  for _,key in ipairs({'h','j','k','l'}) do
    test('mapped Ctrl-'..key..' exits to psmux pane',function()
      command({'select-pane','-t',original}); vim.cmd('only')
      local map=vim.fn.maparg('<C-'..key..'>','n'); assert(map~='','mapping missing')
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-'..key..'>',true,false,true),'xt',false)
      assert(active()~=original,'external pane did not change: '..active())
    end)
  end
  test('zoom prevents leaving Neovim',function()
    command({'select-pane','-t',original}); command({'resize-pane','-Z','-t',original})
    local raw=vim.fn.system("tmux -S "..vim.fn.split(vim.env.TMUX,',')[1].." display-message -p '#{window_zoomed_flag}'")
    report.zoom_raw=raw
    require('nvim-tmux-navigation').NvimTmuxNavigateRight()
    assert(active()==original,'zoomed pane changed')
    assert(command({'display-message','-p','#{window_zoomed_flag}'})=='1','zoom lost')
    command({'resize-pane','-Z','-t',original})
  end)
  test('second session does not steal navigator routing',function()
    command({'-f',root..'/tmux/psmux.conf','new-session','-d','-s','other','--','pwsh','-NoProfile','-File',wait})
    command({'select-pane','-t',original})
    require('nvim-tmux-navigation').NvimTmuxNavigateRight()
    assert(command({'display-message','-p','#{session_name}'})=='probe','wrong session')
    assert(active()~=original,'did not navigate in original session')
  end)
 end)
 report.setup_ok=ok; report.setup_error=not ok and tostring(err) or nil
 vim.fn.writefile({vim.json.encode(report)},assert(vim.env.DOTFILES_PSMUX_RESULT))
 vim.cmd('qa!')
end)
