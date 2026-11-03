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

Set-Item Function:\global:Import-DotfilesGitCompletion -Value {
    if (Get-Module posh-git) { return $true }
    $completionPrompt = (Get-Item Function:\prompt).ScriptBlock
    try {
        Import-Module $completionManifest -Global -ErrorAction Stop
        return $true
    } catch {
        Write-Warning ('Git completion could not be loaded: ' + $_.Exception.Message)
        return $false
    } finally {
        Set-Item Function:\global:prompt -Value $completionPrompt
    }
}.GetNewClosure()

# Importing posh-git costs ~450ms, so load it on the first git Tab instead of at startup.
# posh-git then registers its own completer, which replaces this one.
Register-ArgumentCompleter -Native -CommandName git, tgit, gitk -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    if (-not (Import-DotfilesGitCompletion)) { return }
    # Same padding as posh-git: Expand-GitCommand expects the trailing space that completion strips.
    $padLength = $cursorPosition - $commandAst.Extent.StartOffset
    $textToComplete = $commandAst.ToString().PadRight($padLength, ' ').Substring(0, $padLength)
    Expand-GitCommand $textToComplete
}
