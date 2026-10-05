#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Plan, [switch]$Check, [switch]$SkipInstall, [switch]$InstallOnly)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Git completion setup requires native Windows.' }
$repoPath = Split-Path -Parent $PSScriptRoot
$runtimePath = Join-Path $repoPath 'powershell/git-completion.ps1'
$documentsPath = [Environment]::GetFolderPath('MyDocuments')
if (-not $documentsPath -or -not (Test-Path -LiteralPath $runtimePath -PathType Leaf)) { throw 'Profile source or Documents path is unavailable.' }
$moduleRoot = Join-Path $documentsPath 'WindowsPowerShell/Modules'
$manifest = Join-Path $moduleRoot 'posh-git/1.1.0/posh-git.psd1'
if ($Plan) {
    Write-Output 'Prepare posh-git 1.1.0 in CurrentUser WindowsPowerShell modules (unless SkipInstall); link both profiles to the repository Git completion source, preserving the prompt.'
    return
}
if ($Check) {
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { throw 'posh-git 1.1.0 is missing. Run scripts/setup-git-completion.ps1 or skip Git completion.' }
    Write-Output 'Git completion module is available.'
    return
}
. (Join-Path $PSScriptRoot 'windows-environment.ps1')
Assert-WindowsPowerShellSelection -RepoPath $repoPath
if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
    if ($SkipInstall) { throw 'posh-git 1.1.0 is missing and module installation was skipped. No profiles were changed.' }
    if ($InstallOnly) {
        if (-not (Get-Command Save-PSResource -ErrorAction SilentlyContinue)) {
            throw 'Module preparation requires Save-PSResource (PowerShell 7.4+ or PSResourceGet). No profiles were changed.'
        }
        New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null
        Save-PSResource -Name posh-git -Version 1.1.0 -Repository PSGallery -Path $moduleRoot -TrustRepository
    } else {
        & (Get-Command pwsh -ErrorAction Stop).Source -NoProfile -File $PSCommandPath -InstallOnly
        if ($LASTEXITCODE -ne 0) { throw 'posh-git preparation failed. No profiles were changed.' }
    }
}
if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { throw 'posh-git preparation did not produce the expected manifest.' }
if ($InstallOnly) { return }
$escapedRuntime = $runtimePath.Replace("'", "''")
$loader = ". '$escapedRuntime'"
foreach ($folder in @('WindowsPowerShell', 'PowerShell')) {
    $profilePath = Join-Path $documentsPath "$folder/Microsoft.PowerShell_profile.ps1"
    $existing = ''
    $encoding = [System.Text.UTF8Encoding]::new($true)
    if (Test-Path -LiteralPath $profilePath) {
        $reader = [System.IO.StreamReader]::new($profilePath, $true)
        try { $existing = $reader.ReadToEnd(); $encoding = $reader.CurrentEncoding }
        finally { $reader.Dispose() }
    }
    if (($existing -split '\r?\n') -contains $loader) { continue }
    if (Test-Path -LiteralPath $profilePath) {
        Copy-Item -LiteralPath $profilePath -Destination ($profilePath + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    } else {
        New-Item -ItemType Directory -Path (Split-Path -Parent $profilePath) -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($profilePath, $existing + "`r`n" + $loader + "`r`n", $encoding)
}
Write-Output 'Git completion connected. Open a new PowerShell session.'
