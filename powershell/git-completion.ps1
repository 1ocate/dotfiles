# Runtime source; profiles only link to this checkout. Preserve the existing prompt.
if ($env:OS -ne 'Windows_NT') { return }
$completionRepo = Split-Path -Parent $PSScriptRoot
$selectionPath = Join-Path $completionRepo '.local/environment.json'
if (-not (Test-Path -LiteralPath $selectionPath -PathType Leaf)) { return }
try { $selection = Get-Content -LiteralPath $selectionPath -Raw -Encoding UTF8 | ConvertFrom-Json }
catch { return }
if ($selection.approved -isnot [bool] -or $selection.approved -ne $true -or
    ($null -ne $selection.schemaVersion -and $selection.schemaVersion -ne 1) -or
    $selection.environment -ne 'windows-powershell' -or
    $selection.host -ne [Environment]::MachineName) { return }
$completionManifest = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell/Modules/posh-git/1.1.0/posh-git.psd1'
if (-not (Test-Path -LiteralPath $completionManifest -PathType Leaf)) { return }
$completionPrompt = (Get-Item Function:\prompt).ScriptBlock
try {
    Import-Module $completionManifest -ErrorAction Stop
} catch {
    Write-Warning ('Git completion could not be loaded: ' + $_.Exception.Message)
} finally {
    Set-Item Function:\global:prompt -Value $completionPrompt
}
