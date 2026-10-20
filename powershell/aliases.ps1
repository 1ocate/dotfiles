# Runtime source for Windows PowerShell 5.1 and PowerShell 7.
if ($env:OS -ne 'Windows_NT') { return }
$aliasesRepo = Split-Path -Parent $PSScriptRoot
$aliasesSelectionPath = Join-Path $aliasesRepo '.local/environment.json'
if (-not (Test-Path -LiteralPath $aliasesSelectionPath -PathType Leaf)) { return }
try { $aliasesSelection = Get-Content -LiteralPath $aliasesSelectionPath -Raw -Encoding UTF8 | ConvertFrom-Json }
catch { return }
if ($aliasesSelection.approved -isnot [bool] -or $aliasesSelection.approved -ne $true -or
    ($null -ne $aliasesSelection.schemaVersion -and $aliasesSelection.schemaVersion -ne 1) -or
    $aliasesSelection.environment -ne 'windows-powershell' -or
    $aliasesSelection.host -ne [Environment]::MachineName) { return }
$aliasesNeovim = Get-Command nvim -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $aliasesNeovim) { return }
foreach ($editorAlias in @('vi', 'vim')) {
    try { Set-Alias -Name $editorAlias -Value $aliasesNeovim.Source -Scope Global -ErrorAction Stop }
    catch { Write-Warning ("Could not set $editorAlias to Neovim: " + $_.Exception.Message) }
}
