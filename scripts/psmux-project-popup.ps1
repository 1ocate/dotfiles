#Requires -Version 7.0
# psmux display-popup entry for prefix+F (project picker) and prefix+D (source checkout).
# psmux runs popup commands as `pwsh -NoProfile -Command`, so the picker starts without
# the user profile. fzf is shown before the mux runtime is loaded.
param([string]$Path)
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
try {
    if (-not $Path) {
        . (Join-Path $repository 'powershell/project-picker.ps1')
        $Path = Select-DotfilesProjectPath -Repository $repository
        if (-not $Path) { return }
    }
    . (Join-Path $repository 'powershell/psmux.ps1')
    if (-not (Get-Command Invoke-DotfilesProject -ErrorAction SilentlyContinue)) { throw (Get-DotfilesMuxStatus).Reason }
    Invoke-DotfilesProject -Path $Path
} catch {
    # Keep the popup open so the reason is visible before it closes.
    Write-Host $_.Exception.Message -ForegroundColor Red
    Read-Host 'Press Enter to close' | Out-Null
}
