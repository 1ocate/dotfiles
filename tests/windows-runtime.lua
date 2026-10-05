local ok, err = pcall(function()
  require("lazyvim.config").load("options")
  assert(vim.g.dotfiles_environment == "windows-powershell")
  assert(vim.o.shell == "pwsh" or vim.o.shell == "powershell")
  local output = vim.fn.system("Write-Output 'Windows runtime verified'")
  assert(vim.v.shell_error == 0 and output:find("Windows runtime verified", 1, true), output)
  local unicode = vim.fn.system("Write-Output '한글 검증'")
  assert(vim.v.shell_error == 0 and unicode:find("한글 검증", 1, true), unicode)
  local plugins = require("lazy.core.config").plugins
  assert(not plugins["copilot.lua"] and not plugins["CopilotChat.nvim"], "Copilot was enabled")
  assert(vim.g.autoformat == false)
  -- Exercise the real yank event against a test clipboard, preserving the host clipboard.
  local copied
  local original_setreg = vim.fn.setreg
  vim.fn.setreg = function(register, lines, kind)
    if register == "+" then copied = table.concat(lines, "\n"); return 0 end
    return original_setreg(register, lines, kind)
  end
  require("lazy").load({ plugins = { "yankclip.vim" } })
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "한글 yank 검증" })
  vim.cmd("normal! gg0yy")
  assert(copied == "한글 yank 검증", "Windows yank callback did not copy")
  copied = nil
  vim.g.os_clipboard_enble = 0
  vim.cmd("normal! yy")
  assert(copied == nil, "Disabled yank still copied")
  vim.fn.setreg = original_setreg
  print("PASS: actual isolated LazyVim startup, PowerShell, UTF-8, Copilot/format disabled, yank and toggle (mock clipboard).")
end)
if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
