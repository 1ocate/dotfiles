#Requires -Version 7.0
# psmux display-popup entry for prefix+F (project picker) and prefix+D (source checkout).
# psmux runs popup commands as `pwsh -NoProfile -Command`, so the picker starts without
# the user profile; only the repository runtime is loaded here.
param([string]$Path)
$ErrorActionPreference = 'Stop'
try {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) 'powershell/psmux.ps1')
    if (-not (Get-Command Invoke-DotfilesProject -ErrorAction SilentlyContinue)) { throw (Get-DotfilesMuxStatus).Reason }
    if ($Path) { Invoke-DotfilesProject -Path $Path } else { Invoke-DotfilesProject }
} catch {
    # Keep the popup open so the reason is visible before it closes.
    Write-Host $_.Exception.Message -ForegroundColor Red
    Read-Host 'Press Enter to close' | Out-Null
}
