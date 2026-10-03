#Requires -Version 5.1
# Connect Neovim to this checkout without requiring symlink privileges.
param([switch]$ApprovePowerShell)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This adapter requires native Windows.' }
if (-not $env:LOCALAPPDATA -or -not [System.IO.Path]::IsPathRooted($env:LOCALAPPDATA) -or -not (Test-Path -LiteralPath $env:LOCALAPPDATA -PathType Container)) { throw 'LOCALAPPDATA must be an existing absolute directory.' }
$sourcePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'nvim'
$targetPath = Join-Path $env:LOCALAPPDATA 'nvim'
if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) {
    throw "Neovim configuration not found: $sourcePath"
}
if (-not (Test-Path -LiteralPath (Join-Path $sourcePath 'init.lua') -PathType Leaf)) { throw 'Neovim init.lua is missing.' }
$sourceFull = [System.IO.Path]::GetFullPath($sourcePath).TrimEnd('\')
$targetFull = [System.IO.Path]::GetFullPath($targetPath).TrimEnd('\')
if ($sourceFull -eq $targetFull -or $sourceFull.StartsWith($targetFull + '\', [StringComparison]::OrdinalIgnoreCase) -or $targetFull.StartsWith($sourceFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Neovim source and target must be separate, non-nested directories.'
}
. (Join-Path $PSScriptRoot 'windows-environment.ps1')
Assert-WindowsPowerShellSelection -RepoPath (Split-Path -Parent $PSScriptRoot) -ApprovePowerShell:$ApprovePowerShell
if (Test-Path -LiteralPath $targetPath) {
    $target = Get-Item -LiteralPath $targetPath
    if ($target.LinkType -eq 'Junction' -and $target.Target -contains $sourcePath) {
        Write-Output "Neovim already uses $sourcePath"
        return
    }
    $backupPath = $targetPath + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
    Move-Item -LiteralPath $targetPath -Destination $backupPath
    Write-Output "Previous configuration backed up: $backupPath"
}
New-Item -ItemType Junction -Path $targetPath -Target $sourcePath | Out-Null
Write-Output "Neovim configuration connected: $sourcePath"
