-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
--
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

        -- local bufnr = vim.fn.bufnr("%") -- 현재 버퍼 번호 가져오기
        -- local bufname = vim.fn.bufname(bufnr) -- 현재 버퍼 이름 가져오기
        --
        -- -- 현재 버퍼가 fugitive 버퍼가 아닌 경우에만 닫기
        -- if not string.match(bufname, "^fugitive:///") then
        --   vim.cmd("bwipeout " .. bufnr) -- 현재 버퍼 제거
        --   vim.cmd("Git") -- 다시실행
        -- end
      end
    end
  end,
})
