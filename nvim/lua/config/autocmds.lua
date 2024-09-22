-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
--
-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
--
--
vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = "*.git/COMMIT_EDITMSG",
  callback = function()
    if vim.bo.filetype == "gitcommit" then
      -- CopilotChatCommitStage 명령어 실행
      vim.cmd("CopilotChatCommitStage")
      -- CopilotChatCommitStage 명령어의 출력을 가져와서 커밋 메시지 파일에 삽입
      local output = vim.fn.systemlist("CopilotChatCommitStage")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, output)
    end
  end,
})
-- vim.api.nvim_create_autocmd("BufRead", {
--   pattern = "*.git/COMMIT_EDITMSG",
--   callback = function()
--     if vim.bo.filetype == "gitcommit" then
--       print("Autocmd triggered for gitcommit") -- 디버깅을 위한 출력
--       vim.cmd("CopilotChatCommitStage")
--     end
--   end,
-- })
--
-- vim.api.nvim_create_autocmd("BufWritePost", {
--   pattern = "*.git/COMMIT_EDITMSG",
--   callback = function()
--     if vim.bo.filetype == "gitcommit" then
--       local lines = vim.fn.getline(1, "$") -- 모든 줄 가져오기
--       local commit_message = ""
--       for _, line in ipairs(lines) do
--         if not vim.startswith(line, "#") then
--           commit_message = commit_message .. line .. "\n"
--         end
--       end
--       commit_message = vim.trim(commit_message) -- 앞뒤 공백 제거
--
--       if commit_message ~= "" then -- 커밋 메시지가 비어 있지 않은 경우에만
--         local temp_file = vim.fn.tempname()
--         vim.fn.writefile(vim.split(commit_message, "\n"), temp_file)
--         vim.cmd("Git commit -F " .. temp_file) -- 임시 파일을 사용하여 커밋
--         vim.fn.delete(temp_file) -- 임시 파일 삭제
--       end
--     end
--   end,
-- })
