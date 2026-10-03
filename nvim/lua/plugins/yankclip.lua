-- Clipboard system sync only yank.
return {
  "1ocate/yankclip.vim",
  config = function()
    vim.g.os_clipboard_enble = 1
    vim.keymap.set("n", "<F9>", ":OsYankToggle <CR>")
    -- The upstream plugin handles macOS/WSL only; use Neovim's provider on Windows.
    if vim.fn.has("win32") == 1 and vim.g.dotfiles_environment == "windows-powershell" then
      vim.api.nvim_create_autocmd("TextYankPost", {
        group = vim.api.nvim_create_augroup("WindowsYankClipboard", { clear = true }),
        callback = function()
          if vim.g.os_clipboard_enble == 1 and vim.v.event.operator == "y" then
            vim.fn.setreg("+", vim.v.event.regcontents, vim.v.event.regtype)
          end
        end,
      })
    end
  end,
}
