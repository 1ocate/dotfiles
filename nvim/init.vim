call plug#begin('~/.config/nvim/plugged')

Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'morhetz/gruvbox'
Plug 'preservim/nerdtree'
Plug 'mattn/emmet-vim'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-dispatch'
Plug 'easymotion/vim-easymotion'
Plug 'ludovicchabant/vim-gutentags'
Plug 'junegunn/fzf', { 'dir': '~/opt/fzf' }
Plug 'junegunn/fzf.vim'
Plug 'johngrib/vim-game-code-break'
Plug '1ocate/yankclip.vim'
Plug 'vim-test/vim-test'
Plug 'preservim/tagbar'

call plug#end()
nnoremap <F9> :call <SID>WSLYank_toggle()<CR>

" WSL에서 클립보드에 복사
augroup WSLYank_autocmd

    " 초기화
    let g:wsl_clipboard_enble = 1
    let s:global_yank_cache_0 = @0

    " OS 확인
    if has("mac")
        let s:clip = @+
        let s:flag_able= 1
    elseif has("wsl")
        " WSL의 경우는 클립보드 위치 확인
        let s:clip = '/mnt/c/Windows/System32/clip.exe' 
        if executable(s:clip)
            let s:flag_able= 1
        end
    end

    if  s:flag_able
        autocmd TextYankPost * :call s:WSLYank()
    end

    function! s:WSLYank_toggle()
        let g:wsl_clipboard_enble = ! g:wsl_clipboard_enble
        echom "시스템 클립보드 사용 여부 " . g:wsl_clipboard_enble
        let s:clip = ''
    endfunction

    function! s:save_cache()
        let s:global_yank_cache_0 = @0
    endfunction

    function! s:WSLYank()
            if ! v:true == g:wsl_clipboard_enble
                return
            endif
            if s:global_yank_cache_0 != @0
                if has("wsl")
                    call system('echo '.shellescape(join(v:event.regcontents, "\<CR>")).' | '.s:clip)
                endif
                let @+ = expand(@0)
                call s:save_cache()
                return
            endif
    endfunction

augroup END

"tagbar
nmap <F8> :TagbarToggle<CR>

"dispatch test
let g:dispatch_phpunit_command = './vendor/bin/phpunit'


" 스크롤 할때 구문강조 풀리는 문제 방지 
autocmd BufEnter * syntax sync fromstart

" gutentags 상태
set statusline+=%{gutentags#statusline()}

set nu
set showmatch        " 일치하는 괄호 하이라이팅
set cursorline       " highlight current line
set tabstop=4 softtabstop=4 shiftwidth=4 expandtab smarttab
autocmd FileType javascript setlocal ts=2 sts=2 sw=2 
autocmd FileType typescriptreact setlocal ts=2 sts=2 sw=2
set cindent autoindent smartindent

"테마 변경
let g:gruvbox_contrast_dark = 'hard'
let g:gruvbox_italic = 1
set background=dark
set termguicolors
colorscheme gruvbox


"EucKr 설정
nnoremap <F7> :e ++enc=euc-kr <Cr>

"설정 새로 불러오기
nnoremap <F5> :source % <Cr>

"FZF 설정
let $FZF_DEFAULT_COMMAND='find . \! \( -type d -path ./.git -prune \) \! -type d \! -name ''*.tags'' -printf ''%P\n'''
"let FZF_DEFAULT_COMMAND='rg --hidden -l ""'
"let FZF_DEFAULT_COMMAND="rg --files --hidden --glob '!.git/**' --encoding=euc-kr"


nnoremap <C-p> :Files<Cr>
"nnoremap <S-S> :Files<Cr>
nnoremap <silent> <Leader>rg :Rg <C-R><C-W><CR>
nnoremap <silent> <Leader>tg :Tags <C-R><C-W><CR>

"test 설정
let test#php#phpunit#executable = 'phpunit --stderr'
nmap <silent> <leader>t :TestNearest<CR>
nmap <silent> <leader>T :TestFile<CR>
nmap <silent> <leader>a :TestSuite<CR>
nmap <silent> <leader>l :TestLast<CR>
nmap <silent> <leader>g :TestVisit<CR>

" NERDTree 설정
let g:NERDTreeShowHidden = 1
let g:NERDTreeMinimalUI = 1
let g:NERDTreeIgnore = []
let g:NERDTreeStatusline = ''

" Automaticaly close nvim if NERDTree is only thing left open
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

" NERDTree 단축키
nnoremap <silent> <C-b> :NERDTreeToggle %<CR>

" Terminal
set splitbelow
command! -nargs=* T split | set nonu | resize 5 | term <args>
" turn terminal to normal mode with escape
tnoremap <Esc> <C-\><C-n>

" 하단 바 관련 설정
let g:airline_left_sep = ''
let g:airline_right_sep = ''
let g:airline#extensions#branch#enabled = 1
let g:airline#extensions#tabline#enabled = 1           " enable airline tabline                                                           
let base16colorspace=256  " Access colors present in 256 colorspace

" AIRLINE SETTINGS
let g:airline#extensions#tabline#show_close_button = 0
let g:airline#extensions#tabline#buffer_nr_show = 1
let g:airline_skip_empty_sections = 1
let g:airline#extensions#tabline#fnamemod = ':t'
let g:airline#extensions#syntastic#enabled = 0
let g:airline_detect_iminsert=1
let g:airline#extensions#tmuxline#enabled = 0
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#show_tabs = 1
let g:airline#extensions#tabline#show_buffers = 1
let g:airline#extensions#tabline#tab_nr_type = 1 " tab number
let g:airline#extensions#tabline#show_splits = 1
let g:airline#extensions#wordcount#enabled = 0
let g:airline_theme='base16_horizon_dark'
let g:airline_powerline_fonts = 1
let g:airline#extensions#tagbar#enabled = 1
" END AIRLINE SETTINGS
"
" 이 옵션은 버퍼를 수정한 직후 버퍼를 감춰지도록 한다.
" 이 방법으로 버퍼를 사용하려면 거의 필수다.
set hidden

" 버퍼 새로 열기
" 원래 이 단축키로 바인딩해 두었던 :tabnew를 대체한다.
nmap <leader>T :enew<cr>

" 다음 버퍼로 이동
nmap <leader>l :bnext<CR>

" 이전 버퍼로 이동
nmap <leader>h :bprevious<CR>

" 현재 버퍼를 닫고 이전 버퍼로 이동
" 탭 닫기 단축키를 대체한다.
nmap <leader>bq :bp <BAR> bd #<CR>

" 모든 버퍼와 각 버퍼 상태 출력
nmap <leader>bl :ls<CR>

" Easy motion
let g:EasyMotion_do_mapping  = 0 " Disable default mappings
let g:EasyMotion_startofline = 0 " keep cursor column when JK motion
let g:EasyMotion_smartcase = 1

" 화면에 힌트키가 대문자로 표시되게 한다.
let g:EasyMotion_keys = ' ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890;'
let g:EasyMotion_use_upper = 1

nmap <c-s><c-s> <Plug>(easymotion-overwin-line)

" INSERT 모드에서 입력하면 해당 라인 내에서 좌우로 이동 가능
imap <c-s> <c-o><Plug>(easymotion-lineanywhere)

nmap <c-s>2 <Plug>(easymotion-overwin-f2)

nmap <c-s>l <Plug>(easymotion-lineforward)
vmap <c-s>l <Plug>(easymotion-lineforward)
nmap <c-s>j <Plug>(easymotion-j)
vmap <c-s>j <Plug>(easymotion-j)
nmap <c-s>k <Plug>(easymotion-k)
vmap <c-s>k <Plug>(easymotion-k)
nmap <c-s>h <Plug>(easymotion-linebackward)
vmap <c-s>h <Plug>(easymotion-linebackward)

nmap <c-s>a <Plug>(easymotion-jumptoanywhere)
vmap <c-s>a <Plug>(easymotion-jumptoanywhere)

nmap <c-s>w <Plug>(easymotion-overwin-w)
nmap <c-s>f <Plug>(easymotion-overwin-f)

nmap <c-s>/ <Plug>(easymotion-sn)

" Smartsign (type `3` and match `3`&`#`)
let g:EasyMotion_smartcase = 1
let g:EasyMotion_use_smartsign_us = 1

" vim-choosewin 설정
"nmap <C-s>- <Plug>(choosewin)
"let g:choosewin_overlay_enable = 1
"let g:choosewin_label = 'ASDFQWERZXCV'

"COC 관련 설정

"메뉴창 색상변경
hi CocMenuSel ctermbg=109 guibg=#13354A

" Set internal encoding of vim, not needed on neovim, since coc.nvim using some
" unicode characters in the file autoload/float.vim
"set encoding=utf-8
set fileencodings=utf-8,euc-kr

" TextEdit might fail if hidden is not set.
set hidden

" Some servers have issues with backup files, see #649.
set nobackup
set nowritebackup

" Give more space for displaying messages.
set cmdheight=2

" Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
" delays and poor user experience.
set updatetime=4000

" Don't pass messages to |ins-completion-menu|.
set shortmess+=c

"To make <cr> select the first completion item and confirm the completion when no item has been selected:
inoremap <silent><expr> <cr> coc#pum#visible() ? coc#_select_confirm() : "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

" use <tab> for trigger completion and navigate to the next complete item
function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

inoremap <silent><expr> <Tab>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackspace() ? "\<Tab>" :
      \ coc#refresh()

inoremap <expr> <S-Tab> coc#pum#visible() ? coc#pum#prev(1) : "\<S-Tab>"
