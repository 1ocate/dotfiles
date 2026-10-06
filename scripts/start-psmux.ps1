#Requires -Version 5.1
# WezTerm entry point: no automatic install and no nested multiplexer.
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'psmux launcher requires native Windows.' }
$repoPath = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoPath 'powershell/psmux.ps1')
if ((Get-Command Invoke-DotfilesMux -ErrorAction SilentlyContinue) -and -not $env:TMUX) {
    try { Invoke-DotfilesMux }
    catch { Write-Warning ('psmux could not start: ' + $_.Exception.Message) }
}
$plainShell = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $plainShell) { $plainShell = Get-Command powershell -ErrorAction Stop }
& $plainShell.Source -NoLogo -NoExit
