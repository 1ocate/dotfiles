-- Clipboard system sync only yank.
return {
  "1ocate/yankclip.vim",
  config = function()
    vim.g.os_clipboard_enble = 1
    vim.keymap.set("n", "<F9>", ":OsYankToggle <CR>")
  end,
}
