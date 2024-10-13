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

-- 오동작으로 인한 라인이동 키맵 해제
vim.api.nvim_del_keymap("n", "<A-j>")
vim.api.nvim_del_keymap("n", "<A-k>")
vim.api.nvim_del_keymap("i", "<A-j>")
vim.api.nvim_del_keymap("i", "<A-k>")

vim.keymap.set("n", "<C-h>", "<Cmd>NvimTmuxNavigateLeft<CR>", { silent = true })
vim.keymap.set("n", "<C-j>", "<Cmd>NvimTmuxNavigateDown<CR>", { silent = true })
vim.keymap.set("n", "<C-k>", "<Cmd>NvimTmuxNavigateUp<CR>", { silent = true })
vim.keymap.set("n", "<C-l>", "<Cmd>NvimTmuxNavigateRight<CR>", { silent = true })
