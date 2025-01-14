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
      local lines = vim.fn.getline(1, "$") -- 모든 줄 가져오기
      local commit_message = ""
      for _, line in ipairs(lines) do
        if not vim.startswith(line, "#") then
          commit_message = commit_message .. line .. "\n"
        end
      end
      commit_message = vim.trim(commit_message) -- 앞뒤 공백 제거

      if commit_message ~= "" then -- 커밋 메시지가 비어 있지 않은 경우에만
        local temp_file = vim.fn.tempname()
        vim.fn.writefile(vim.split(commit_message, "\n"), temp_file)
        vim.cmd("Git commit -F " .. temp_file) -- 임시 파일을 사용하여 커밋
        vim.fn.delete(temp_file) -- 임시 파일 삭제

        -- .git/COMMIT_EDITMSG 버퍼 닫기
        local bufnr = vim.fn.bufnr(".git/COMMIT_EDITMSG") -- 파일 이름으로 버퍼 번호 가져오기
        if bufnr ~= -1 then -- 버퍼가 존재하는 경우에만
          vim.cmd("bwipeout " .. bufnr) -- 버퍼 제거
        end
      end
    end
  end,
})
