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
      local commit_message = vim.fn.getline(1) -- 첫 번째 줄의 커밋 메시지 가져오기
      if commit_message ~= "" then -- 커밋 메시지가 비어 있지 않은 경우에만
        vim.cmd("w") -- 파일 저장
        vim.cmd("Git commit -F %") -- 커밋 메시지 파일을 사용하여 커밋
        local bufnr = vim.fn.bufnr("%") -- 현재 버퍼 번호 가져오기
        local bufname = vim.fn.bufname(bufnr) -- 현재 버퍼 이름 가져오기

        -- 현재 버퍼가 fugitive 버퍼가 아닌 경우에만 닫기
        if not string.match(bufname, "^fugitive://") then
          vim.cmd("bwipeout " .. bufnr) -- 현재 버퍼 제거
        end
      end
    end
  end,
})
