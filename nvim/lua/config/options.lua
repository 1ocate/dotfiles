-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- vim 클립보드 연동 해제
vim.cmd("set clipboard=")

-- 커서 라인 및 컬럼 활성화 (필요 시 주석 해제)
-- vim.opt.cursorline = true
-- vim.opt.cursorcolumn = true

-- 들여쓰기 설정
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.cindent = true
vim.opt.autoindent = true
vim.opt.smartindent = true

-- 파일 인코딩 설정
vim.opt.fileencodings = "utf-8,euc-kr"
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"

-- 업데이트 시간 설정
vim.opt.updatetime = 4000

-- 줄 바꿈 비활성화
vim.opt.wrap = false

-- 줄 번호 표시
vim.opt.number = true
vim.opt.relativenumber = true

-- 자동 완성 설정
vim.opt.wildmode = "longest:full,full"

-- 제목 표시줄 활성화
vim.opt.title = true

-- 모든 모드에서 마우스 사용 가능
vim.opt.mouse = "a"

-- 터미널 GUI 색상 활성화
vim.opt.termguicolors = true

-- 맞춤법 검사 활성화 (필요 시 주석 해제)
-- vim.opt.spell = true

-- 검색 설정
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- 특수 문자 표시 설정
vim.opt.list = true
vim.opt.listchars = { tab = "▸ ", trail = "·" }
vim.opt.fillchars:append({ eob = " " })

-- 창 분할 설정
vim.opt.splitbelow = true
vim.opt.splitright = true

-- 스크롤 오프셋 설정
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8

-- 오류 대신 확인 요청
vim.opt.confirm = true

-- 지속적인 되돌리기
vim.opt.undofile = true

-- 백업 설정
vim.opt.backupdir:remove(".")
vim.opt.backup = true

-- WSL용 설정
if osName == "WSL" then
  vim.cmd([[
    set noeol
    set nofixeol
  ]])
end

-- 버퍼용 설정
vim.opt.hidden = true

-- PHP용 LSP 서버 설정
vim.g.lazyvim_php_lsp = "intelephense"

-- Diff 하이라이트 설정
vim.cmd("highlight DiffAdd guibg=#006400 guifg=#FFFFFF")
vim.cmd("highlight DiffChange guibg=#00008B guifg=#FFFFFF")
vim.cmd("highlight DiffDelete guibg=#8B0000 guifg=#FFFFFF")
vim.cmd("highlight Visual guibg=#006400 guifg=#FFFFFF")

-- 저장할 때 자동 포맷 비활성화
vim.g.format_on_save = false
