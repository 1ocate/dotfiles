# Runtime source for Windows PowerShell 5.1 and PowerShell 7.
if ($env:OS -ne 'Windows_NT') { return }
$aliasesNeovim = Get-Command nvim -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $aliasesNeovim) { return }
foreach ($editorAlias in @('vi', 'vim')) {
    try { Set-Alias -Name $editorAlias -Value $aliasesNeovim.Source -Scope Global -ErrorAction Stop }
    catch { Write-Warning ("Could not set $editorAlias to Neovim: " + $_.Exception.Message) }
}
