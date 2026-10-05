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
  require("lazyvim.config").load("keymaps")
  require("lazy").load({ plugins = { "nvim-tmux-navigation", "telescope.nvim" } })
  local selected_picker = LazyVim.pick.picker
  local actual_command
  local original_open = selected_picker.open
  selected_picker.open = function(command) actual_command = command end
  dofile(vim.fn.stdpath("config") .. "/lua/plugins/telescope.lua").keys[3][2]()
  selected_picker.open = original_open
  assert(actual_command == (selected_picker.commands.files or "files"), "All-files key used an unsupported picker command")
  local first_window = vim.api.nvim_get_current_win()
  vim.cmd("vsplit")
  local second_window = vim.api.nvim_get_current_win()
  assert(first_window ~= second_window)
  vim.cmd("NvimTmuxNavigateLeft")
  assert(vim.api.nvim_get_current_win() == first_window)
  vim.cmd("NvimTmuxNavigateRight")
  assert(vim.api.nvim_get_current_win() == second_window)
  vim.cmd("close")
  local sample = vim.fn.getcwd() .. "/sample.md"
  vim.cmd("edit " .. vim.fn.fnameescape(sample))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# 한글 저장 검증", "find-this-marker" })
  vim.cmd("write")
  assert(vim.fn.readfile(sample)[1] == "# 한글 저장 검증")
  local matches = vim.fn.system({ "rg", "--no-heading", "find-this-marker", sample })
  assert(vim.v.shell_error == 0 and matches:find("find-this-marker", 1, true))
  require("telescope.builtin").find_files({ cwd = vim.fn.getcwd() })
  vim.wait(1000)
  local picker = require("telescope.actions.state").get_current_picker(vim.api.nvim_get_current_buf())
  assert(picker and picker.manager:num_results() > 0, "File picker returned no files")
  require("telescope.actions").close(picker.prompt_bufnr)
  local terminal = Snacks.terminal.open({ vim.o.shell, "-NoLogo", "-NoProfile", "-Command",
    "Write-Output 'terminal-runtime-marker'; Start-Sleep -Seconds 20" },
    { cwd = vim.fn.getcwd(), auto_close = false })
  assert(terminal and vim.api.nvim_buf_is_valid(terminal.buf), "Floating terminal failed")
  local job = vim.b[terminal.buf].terminal_job_id
  assert(job > 0 and vim.fn.jobwait({ job }, 0)[1] == -1, "Floating terminal job did not start")
  vim.fn.jobstop(job)
  terminal:close()
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
  vim.cmd("OsYankToggle")
  assert(vim.g.os_clipboard_enble == 0)
  vim.cmd("normal! yy")
  assert(copied == nil, "Disabled yank still copied")
  vim.fn.setreg = original_setreg
  print("PASS: isolated startup, PowerShell/UTF-8, save/search/picker, split navigation, floating terminal, Copilot/format disabled, yank/F9 command (mock clipboard).")
end)
if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
