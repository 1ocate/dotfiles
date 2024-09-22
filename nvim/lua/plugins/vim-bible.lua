return {
  "1ocate/vim-bible",
  config = function()
    vim.g.BibleTranslation = "KorRv"
    vim.g.BibleLocale = "en"
    vim.cmd([[
      "noremap <Leader>b y :d_ <bar> :call bible#insert_quote(substitute(@", '\n$', '', ''))<CR>
      vnoremap <silent> <Leader>b y :d_ <bar> :call bible#insert_quote(substitute(@", '\n$', '', ''))<CR>
    ]])
  end,
}
