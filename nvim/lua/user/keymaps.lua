-- -- Space is my leader.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true })

-- Reselect visual selection after indenting.
vim.keymap.set('v', '<', '<gv')
vim.keymap.set('v', '>', '>gv')

-- visual 모드에서 yank시 커서 제자리로 설정(설정되면 register로 복사 안되는 문제로 토글 생성)
-- Maintain the cursor position when yanking a visual selection.
-- http://ddrscott.github.io/blog/2016/yank-without-jank/
local function updateVisualSelectMapping()
    local mapping = visualSelectMode and 'myy`y' or 'y'
    vim.keymap.set('v', 'y', mapping)
end

local function toggleVisualSelectMode()
    visualSelectMode = not visualSelectMode
    updateVisualSelectMapping()
    print("Visual select mode: " .. (visualSelectMode and "true" or "false"))
end

updateVisualSelectMapping()
vim.keymap.set('n', '<F6>', toggleVisualSelectMode)

-- Disable annoying command line typo.
vim.keymap.set('n', 'q:', ':q')

-- Paste replace visual selection without copying it.
vim.keymap.set('v', 'p', '"_dP')

-- Easy insertion of a trailing ; or , from insert mode.
vim.keymap.set('i', ';;', '<Esc>A;')
vim.keymap.set('i', ',,', '<Esc>A,')

-- Quickly clear search highlighting.
vim.keymap.set('n', '<Leader>k', ':nohlsearch<CR>')

-- Open the current file in the default program (on Mac this should just be just `open`).
vim.keymap.set('n', '<Leader>x', ':!xdg-open %<CR><CR>')

 -- Move lines up and down.
-- vim.keymap.set('i', '<A-k>', '<Esc>:move .-2<CR>==gi')
-- vim.keymap.set('i', '<A-j>', '<Esc>:move .+1<CR>==gi')
-- vim.keymap.set('n', '<A-j>', ':move .+1<CR>==')
-- vim.keymap.set('n', '<A-k>', ':move .-2<CR>==')
vim.keymap.set('v', '<A-k>', ":move '<-2<CR>gv=gv")
vim.keymap.set('v', '<A-j>', ":move '>+1<CR>gv=gv")

-- For Buffer Control
-- :tabnew 대체
-- vim.keymap.set('n', '<leader>T', ':enew<CR>')

-- 현재 버퍼를 닫고 이전 버퍼로 이동
-- 탭 닫기 단축키를 대체한다.
vim.keymap.set('n', '<leader>bq', ':bp <BAR> bd #<CR>')


-- EucKr 설정
vim.keymap.set('n', '<F7>', ':e ++enc=euc-kr <CR>')

-- 설정 새로 불러오기
vim.keymap.set('n', '<F5>', ':source % <CR>')

-- 성경 열기
vim.keymap.set('n', '<F8>', function()
  local bible_bufnr = nil
  for _, bufinfo in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    local bufname = vim.fn.bufname(bufinfo.bufnr)
    if bufname and bufname:find('bible%.txt$') then
      bible_bufnr = bufinfo.bufnr
      break
    end
  end

  if bible_bufnr then
    vim.cmd(string.format(':bd! %d', bible_bufnr))
  else
    vim.cmd(':leftabove vs')
    vim.cmd(':e ~/bible.txt')
    vim.cmd(':set wrap')
    vim.cmd(':vertical resize 40')
  end

end)

-- git MerginalToggle
vim.keymap.set('n', '<F4>', function()
    vim.opt.splitbelow = false
    vim.opt.splitright = false
    vim.cmd(':MerginalToggle')
    vim.opt.splitbelow = true
    vim.opt.splitright = true
end)

vim.keymap.set('n', '<leader>c', ':CopilotChatToggle <CR>')


-- Git 커밋 메시지 버퍼가 열릴 때 특정 명령 실행
vim.api.nvim_create_autocmd("FileType", {
  pattern = "gitcommit",
  callback = function()
    vim.cmd('CopilotChatCommitStage')
  end,
})
