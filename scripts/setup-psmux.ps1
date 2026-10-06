#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Plan, [switch]$Check, [switch]$SkipInstall, [switch]$InstallOnly, [switch]$Disable)
$ErrorActionPreference = 'Stop'
if ($InstallOnly -and $Disable) { throw 'InstallOnly and Disable cannot be combined.' }
if ($env:OS -ne 'Windows_NT') { throw 'psmux setup requires native Windows.' }
$repoPath = Split-Path -Parent $PSScriptRoot
$version = '3.3.8'
$zipHash = '1AD127BA937194A890B933A73D9B023E297BD73DC742ABD841BF159984C2EFFE'
$installPath = Join-Path $env:LOCALAPPDATA "Programs/psmux/$version"
$runtimePath = Join-Path $repoPath 'powershell/psmux.ps1'
$featurePath = Join-Path $repoPath '.local/psmux.json'
$documentsPath = [Environment]::GetFolderPath('MyDocuments')
foreach ($source in @($runtimePath, (Join-Path $repoPath 'tmux/psmux.conf'), (Join-Path $repoPath 'scripts/start-psmux.ps1'))) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing psmux source: $source" }
}
if (-not $documentsPath -or -not $env:LOCALAPPDATA -or -not [System.IO.Path]::IsPathRooted($env:LOCALAPPDATA)) {
    throw 'User Documents or LOCALAPPDATA is unavailable.'
}
. (Join-Path $PSScriptRoot 'windows-environment.ps1')
if ($Plan) {
    Write-WindowsSelectionStatus -RepoPath $repoPath
    Write-Output "Optional windows-powershell: pinned psmux $version x64 portable release (SHA256 checked) in $installPath."
    Write-Output 'Link both user profiles to the runtime source; add tmux.exe directory to user PATH; enable WezTerm launcher in host-local state.'
    Write-Output 'Disable only changes the feature marker; sessions and backed-up user files remain intact.'
    return
}
if ($Check) {
    Write-WindowsSelectionStatus -RepoPath $repoPath
    foreach ($binary in @('psmux.exe', 'tmux.exe')) {
        if (-not (Test-Path (Join-Path $installPath $binary) -PathType Leaf)) { throw "Missing $binary. Run setup-psmux.ps1 to prepare the pinned release." }
    }
    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) { throw 'PowerShell 7 is required for psmux panes.' }
    Write-Output 'psmux sources, binaries and PowerShell 7 are available (read-only; no server started).'
    return
}
Assert-WindowsPowerShellSelection -RepoPath $repoPath
if ($Disable) {
    if (Test-Path -LiteralPath $featurePath) {
        $state = Get-Content $featurePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($state.host -ne [Environment]::MachineName -or $state.schemaVersion -ne 1) { throw 'psmux state belongs to another host or schema.' }
        $state.enabled = $false
        $state | ConvertTo-Json | Set-Content -LiteralPath $featurePath -Encoding UTF8
    }
    Write-Output 'psmux automatic startup disabled. Existing sessions are preserved; reopen WezTerm.'
    return
}
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) { throw 'PowerShell 7 is required; no profiles have been changed.' }
if ((Get-CimInstance Win32_OperatingSystem).OSArchitecture -notmatch '64' -or
    ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -and $env:PROCESSOR_ARCHITEW6432 -ne 'AMD64')) {
    throw 'This pinned psmux package supports Windows x64 only.'
}
if (Test-Path -LiteralPath $featurePath) {
    $previous = Get-Content $featurePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($previous.host -ne [Environment]::MachineName -or $previous.schemaVersion -ne 1) { throw 'Existing psmux state belongs to another host or schema.' }
}
if (-not (Test-Path -LiteralPath $installPath -PathType Container)) {
    if ($SkipInstall) { throw 'Pinned psmux is missing and installation was skipped. No profiles were changed.' }
    $stagePath = Join-Path $env:TEMP ('dotfiles-psmux-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $stagePath | Out-Null
    $zipPath = Join-Path $stagePath 'psmux.zip'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/psmux/psmux/releases/download/v$version/psmux-v$version-windows-x64.zip" -OutFile $zipPath
    if ((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash -ne $zipHash) { throw 'psmux release SHA256 mismatch. No profiles were changed.' }
    $expandedPath = Join-Path $stagePath 'expanded'
    Expand-Archive -LiteralPath $zipPath -DestinationPath $expandedPath
    foreach ($binary in @('psmux.exe', 'tmux.exe')) {
        if (-not (Test-Path (Join-Path $expandedPath $binary) -PathType Leaf)) { throw "Release is missing $binary." }
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $installPath) -Force | Out-Null
    Move-Item -LiteralPath $expandedPath -Destination $installPath
}
foreach ($binary in @('psmux.exe', 'tmux.exe')) {
    if (-not (Test-Path (Join-Path $installPath $binary) -PathType Leaf)) { throw "Existing install lacks $binary; preserve it and repair separately. No profiles were changed." }
    $reportedVersion = & (Join-Path $installPath $binary) -V
    if ($LASTEXITCODE -ne 0 -or ($reportedVersion -join ' ') -notmatch 'tmux 3\.3\.8') { throw "Unexpected $binary version. No profiles were changed." }
}
if ($InstallOnly) {
    Write-Output 'Pinned psmux binaries verified; profiles, PATH and feature state unchanged.'
    return
}
$loader = ". '" + $runtimePath.Replace("'", "''") + "'"
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
    } else { New-Item -ItemType Directory -Path (Split-Path -Parent $profilePath) -Force | Out-Null }
    [System.IO.File]::WriteAllText($profilePath, $existing + "`r`n" + $loader + "`r`n", $encoding)
}
$userPath = [string][Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $installPath) {
    [System.IO.File]::WriteAllText((Join-Path $repoPath ('.local/path-before-psmux-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.txt')), [string]$userPath)
    [Environment]::SetEnvironmentVariable('Path', $userPath.TrimEnd(';') + ';' + $installPath, 'User')
}
$state = [ordered]@{ schemaVersion = 1; host = [Environment]::MachineName; enabled = $true; version = $version }
$state | ConvertTo-Json | Set-Content -LiteralPath $featurePath -Encoding UTF8
Write-Output 'psmux prepared and source profile loaders connected. Reopen WezTerm to enter the main session.'
