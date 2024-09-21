-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
--
vim.api.nvim_create_autocmd("BufRead", {
  pattern = "*.git/COMMIT_EDITMSG",
  callback = function()
    if vim.bo.filetype == "gitcommit" then
      print("Autocmd triggered for gitcommit") -- 디버깅을 위한 출력
      vim.cmd("CopilotChatCommitStage")
    end
  end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.git/COMMIT_EDITMSG",
  callback = function()
    if vim.bo.filetype == "gitcommit" then
      vim.cmd("w") -- 파일 저장
      vim.cmd("Git commit -F %") -- 커밋 메시지 파일을 사용하여 커밋
    end
  end,
})
