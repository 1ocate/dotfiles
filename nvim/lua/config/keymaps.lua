-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "<leader>gg", ":Git<CR>")

-- 성경 열기
vim.keymap.set("n", "<F8>", function()
  local bible_bufnr = nil
  for _, bufinfo in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    local bufname = vim.fn.bufname(bufinfo.bufnr)
    if bufname and bufname:find("bible%.txt$") then
      bible_bufnr = bufinfo.bufnr
      break
    end
  end

  if bible_bufnr then
    vim.cmd(string.format(":bd! %d", bible_bufnr))
  else
    vim.cmd(":leftabove vs")
    vim.cmd(":e ~/bible.txt")
    vim.cmd(":set wrap")
    vim.cmd(":vertical resize 40")
  end
end)
