#Requires -Version 5.1
<#
Connect the current dotfiles checkout to WezTerm on Windows.
Existing user configuration is backed up; repeating this command is safe.
#>
param([switch]$ApprovePowerShell)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This adapter requires native Windows.' }

$repoPath = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repoPath '.wezterm.lua'
$profileDirectory = [Environment]::GetFolderPath('UserProfile')
if (-not $profileDirectory -or -not (Test-Path -LiteralPath $profileDirectory -PathType Container)) { throw 'User profile directory is unavailable.' }
$targetPath = Join-Path $profileDirectory '.wezterm.lua'
if ([System.IO.Path]::GetFullPath($sourcePath) -eq [System.IO.Path]::GetFullPath($targetPath)) { throw 'Source and target must differ; move the checkout outside the user profile root.' }
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "WezTerm configuration not found: $sourcePath"
}
. (Join-Path $PSScriptRoot 'windows-environment.ps1')
if (-not (Test-Path -LiteralPath (Join-Path $repoPath 'environment.lua') -PathType Leaf)) { throw 'Shared environment.lua is missing.' }
Assert-WindowsPowerShellSelection -RepoPath $repoPath -ApprovePowerShell:$ApprovePowerShell

# A small loader works without Windows symlink privileges and follows repo edits.
$luaPath = $sourcePath.Replace('\', '/').Replace("'", "\'")
$loader = @"
-- Managed by dotfiles/scripts/use-wezterm.ps1
local wezterm = require 'wezterm'
local source = '$luaPath'
wezterm.add_to_config_reload_watch_list(source)
return dofile(source)
"@

if (Test-Path -LiteralPath $targetPath) {
    $existing = [System.IO.File]::ReadAllText($targetPath)
    if ($existing.TrimEnd() -eq $loader.TrimEnd()) {
        Write-Output "WezTerm already uses $sourcePath"
        return
    }
    $backupPath = $targetPath + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
    Move-Item -LiteralPath $targetPath -Destination $backupPath
    Write-Output "Previous configuration backed up: $backupPath"
}

[System.IO.File]::WriteAllText($targetPath, $loader + "`n", [System.Text.UTF8Encoding]::new($false))
Write-Output "WezTerm configuration connected: $sourcePath"
