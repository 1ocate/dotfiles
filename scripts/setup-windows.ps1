#Requires -Version 5.1
<#
Native Windows bootstrap based on the configuration verified on 2026-10-03.
Run -Plan to review without installing or changing anything.
#>
[CmdletBinding()]
param(
    [ValidateSet('windows-terminal', 'wezterm')][string]$Terminal = 'windows-terminal',
    [switch]$Plan,
    [switch]$Check,
    [switch]$ApprovePowerShell,
    [switch]$SkipPackages,
    [switch]$WithPsmux,
    [switch]$SkipFonts,
    [switch]$SkipPlugins,
    [switch]$SkipGitCompletion,
    [switch]$SkipAutoHotkey,
    [switch]$RegisterAutoHotkeyStartup,
    [switch]$SkipAutoHotkeyStartup
)

$ErrorActionPreference = 'Stop'
if ($RegisterAutoHotkeyStartup -and $SkipAutoHotkeyStartup) {
    throw 'RegisterAutoHotkeyStartup and SkipAutoHotkeyStartup cannot be combined.'
}

function Resolve-AutoHotkeyStartup {
    param([bool]$Register, [bool]$Skip, [bool]$SkipCurrentRun, [bool]$Interactive)
    if ($Register) { return $true }
    if ($Skip -or $SkipCurrentRun -or -not $Interactive) { return $false }
    $answer = Read-Host 'Register AutoHotkey to start at Windows login? [y/N]'
    return $answer -match '^(?i:y|yes)$'
}

if ($env:OS -ne 'Windows_NT') { throw 'This setup requires native Windows.' }

$repoPath = Split-Path -Parent $PSScriptRoot
$terminalPackage = if ($Terminal -eq 'windows-terminal') { 'Microsoft.WindowsTerminal' } else { 'wez.wezterm' }
$terminalCommand = if ($Terminal -eq 'windows-terminal') { 'wt' } else { 'wezterm' }
$terminalAdapter = if ($Terminal -eq 'windows-terminal') { 'use-windows-terminal.ps1' } else { 'use-wezterm.ps1' }
$packages = @(
    'Git.Git',
    'Microsoft.PowerShell',
    'JanDeDobbeleer.OhMyPosh',
    'AutoHotkey.AutoHotkey',
    $terminalPackage,
    'Neovim.Neovim',
    'OpenJS.NodeJS.LTS',
    'BurntSushi.ripgrep.MSVC',
    'sharkdp.fd',
    'junegunn.fzf',
    'BrechtSanders.WinLibs.POSIX.UCRT',
    'Python.Python.3.13'
)

if ($Plan) {
    . (Join-Path $PSScriptRoot 'windows-environment.ps1')
    Write-WindowsSelectionStatus -RepoPath $repoPath
    Write-Output "windows-powershell setup from: $repoPath"
    Write-Output 'First setup requires -ApprovePowerShell; later runs reuse the local host selection.'
    if (-not $SkipPackages) { Write-Output ('Install missing winget packages: ' + ($packages -join ', ')) }
    if ($WithPsmux) { & (Join-Path $PSScriptRoot 'setup-psmux.ps1') -Plan }
    Write-Output "Connect $Terminal and Neovim to this checkout, backing up previous settings."
    if ($Terminal -eq 'windows-terminal') { & (Join-Path $PSScriptRoot $terminalAdapter) -Plan }
    else { Write-Output ('WezTerm loader source: ' + (Join-Path $repoPath '.wezterm.lua')) }
    Write-Output 'Add Oh My Posh initialization to the 5.1 and 7 user profiles.'
    if (-not $SkipGitCompletion) { & (Join-Path $PSScriptRoot 'setup-git-completion.ps1') -Plan }
    Write-Output 'Set CurrentUser RemoteSigned only if it is currently Undefined or Restricted.'
    if (-not $SkipFonts) { & (Join-Path $PSScriptRoot 'setup-meslo-font.ps1') -Plan }
    if (-not $SkipPlugins) { Write-Output 'Install/restore Neovim plugins from lazy-lock.json and install syntax parsers/tools.' }
    if (-not $SkipAutoHotkey) { Write-Output 'Start the AutoHotkey v2 script in the background.' }
    if ($RegisterAutoHotkeyStartup) { Write-Output 'Register the optional AutoHotkey login shortcut.' }
    elseif (-not $SkipAutoHotkeyStartup -and -not $SkipAutoHotkey) { Write-Output 'Ask about AutoHotkey login startup in an interactive setup (default: No); skip registration otherwise.' }
    return
}

if (-not $SkipFonts) {
    foreach ($fontSource in @('fonts/meslo.json', 'scripts/setup-meslo-font.ps1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $repoPath $fontSource) -PathType Leaf)) { throw "Required font source not found: $fontSource" }
    }
}

$terminalSources = if ($Terminal -eq 'windows-terminal') { @('windows-terminal/settings.json', 'scripts/use-windows-terminal.ps1') } else { @('.wezterm.lua', 'environment.lua', 'scripts/use-wezterm.ps1') }
foreach ($relativePath in ($terminalSources + @( 'autoHotKey.ahk', 'nvim/init.lua', 'nvim/lazy-lock.json', 'scripts/use-neovim.ps1', 'scripts/setup-neovim.lua', 'scripts/windows-environment.ps1', 'scripts/environment.py', 'scripts/setup-git-completion.ps1', 'powershell/git-completion.ps1'))) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoPath $relativePath) -PathType Leaf)) {
        throw "Required file not found: $relativePath"
    }
}

function Update-SetupPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
        [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Test-SetupPrerequisites {
    $requiredCommands = @($terminalCommand, 'nvim', 'pwsh', 'oh-my-posh')
    if (-not $SkipGitCompletion) { $requiredCommands += 'git' }
    if (-not $SkipPlugins) { $requiredCommands += @('git', 'node', 'npm', 'rg', 'fd', 'fzf', 'gcc', 'python') }
    $missing = @($requiredCommands | Where-Object { -not (Get-Command $_ -CommandType Application -ErrorAction SilentlyContinue) })
    if (-not $SkipAutoHotkey -or $RegisterAutoHotkeyStartup) {
        $candidates = @(
            (Join-Path $env:LOCALAPPDATA 'Programs/AutoHotkey/v2/AutoHotkey64.exe'),
            (Join-Path $env:ProgramFiles 'AutoHotkey/v2/AutoHotkey64.exe')
        )
        if (-not ($candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })) { $missing += 'AutoHotkey v2' }
    }
    if ($missing.Count) { throw ('Missing required tools: ' + ($missing -join ', ') + '. Install dependencies or skip the corresponding optional feature. No configuration has been changed.') }
    Write-Output 'Local prerequisites passed.'
}

foreach ($variableName in @('LOCALAPPDATA', 'USERPROFILE', 'ProgramFiles', 'WINDIR')) {
    $directory = [Environment]::GetEnvironmentVariable($variableName)
    if (-not $directory -or -not [System.IO.Path]::IsPathRooted($directory) -or -not (Test-Path -LiteralPath $directory -PathType Container)) {
        throw "Invalid Windows directory: $variableName"
    }
}
if (-not [Environment]::GetFolderPath('MyDocuments')) { throw 'User Documents directory is unavailable.' }
$nvimSource = [System.IO.Path]::GetFullPath((Join-Path $repoPath 'nvim')).TrimEnd('\')
$nvimTarget = [System.IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'nvim')).TrimEnd('\')
if ($nvimSource -eq $nvimTarget -or $nvimSource.StartsWith($nvimTarget + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or $nvimTarget.StartsWith($nvimSource + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Neovim source and target must be separate, non-nested directories.'
}
if ($Terminal -eq 'wezterm' -and [System.IO.Path]::GetFullPath((Join-Path $repoPath '.wezterm.lua')) -eq [System.IO.Path]::GetFullPath((Join-Path ([Environment]::GetFolderPath('UserProfile')) '.wezterm.lua'))) {
    throw 'WezTerm source and target must differ; move the checkout outside the user profile root.'
}
if ($Check) {
    . (Join-Path $PSScriptRoot 'windows-environment.ps1')
    Write-WindowsSelectionStatus -RepoPath $repoPath
    Update-SetupPath
    Test-SetupPrerequisites
    if ($Terminal -eq 'windows-terminal') { & (Join-Path $PSScriptRoot $terminalAdapter) -Check }
    else { Write-Output ('WezTerm loader target: ' + (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.wezterm.lua')) }
    if (-not $SkipFonts) { & (Join-Path $PSScriptRoot 'setup-meslo-font.ps1') -Check }
    if ($WithPsmux) { & (Join-Path $PSScriptRoot 'setup-psmux.ps1') -Check }
    if (-not $SkipGitCompletion) { & (Join-Path $PSScriptRoot 'setup-git-completion.ps1') -Check }
    return
}

. (Join-Path $PSScriptRoot 'windows-environment.ps1')
Assert-WindowsPowerShellSelection -RepoPath $repoPath -ApprovePowerShell:$ApprovePowerShell
$interactiveSetup = [Environment]::UserInteractive -and -not [Console]::IsInputRedirected -and
    -not ([Environment]::GetCommandLineArgs() -match '^-NonI')
$RegisterAutoHotkeyStartup = Resolve-AutoHotkeyStartup -Register $RegisterAutoHotkeyStartup `
    -Skip $SkipAutoHotkeyStartup -SkipCurrentRun $SkipAutoHotkey -Interactive $interactiveSetup

if (-not $SkipPackages) {
    $winget = (Get-Command winget -ErrorAction Stop).Source
    foreach ($packageId in $packages) {
        $listing = & $winget list --id $packageId --exact --source winget --accept-source-agreements --disable-interactivity 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Output "Already installed: $packageId"
            continue
        }
        Write-Output "Installing: $packageId"
        & $winget install --id $packageId --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -ne 0) { throw "winget installation failed: $packageId ($LASTEXITCODE)" }
    }
}
Update-SetupPath
Test-SetupPrerequisites
if (-not $SkipFonts) { & (Join-Path $PSScriptRoot 'setup-meslo-font.ps1') }
if ($WithPsmux) { & (Join-Path $PSScriptRoot 'setup-psmux.ps1') -InstallOnly -SkipInstall:$SkipPackages }

if (-not $SkipGitCompletion) {
    & (Join-Path $PSScriptRoot 'setup-git-completion.ps1') -SkipInstall:$SkipPackages
}

& (Join-Path $PSScriptRoot $terminalAdapter)
& (Join-Path $PSScriptRoot 'use-neovim.ps1')

$documentsPath = [Environment]::GetFolderPath('MyDocuments')
$initLine = 'oh-my-posh init pwsh --eval | Invoke-Expression'
foreach ($profileFolder in @('WindowsPowerShell', 'PowerShell')) {
    $profilePath = Join-Path $documentsPath "$profileFolder/Microsoft.PowerShell_profile.ps1"
    New-Item -ItemType Directory -Path (Split-Path -Parent $profilePath) -Force | Out-Null
    if (Test-Path -LiteralPath $profilePath) {
        $profileReader = [System.IO.StreamReader]::new($profilePath, $true)
        try {
            $existing = $profileReader.ReadToEnd()
            $profileEncoding = $profileReader.CurrentEncoding
        } finally {
            $profileReader.Dispose()
        }
        if ($existing -match 'oh-my-posh\s+init') { continue }
        Copy-Item -LiteralPath $profilePath -Destination ($profilePath + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
        [System.IO.File]::AppendAllText($profilePath, "`r`n" + $initLine + "`r`n", $profileEncoding)
    } else {
        [System.IO.File]::WriteAllText($profilePath, $initLine + "`r`n", [System.Text.UTF8Encoding]::new($true))
    }
}
if ($WithPsmux) { & (Join-Path $PSScriptRoot 'setup-psmux.ps1') -SkipInstall }

if ((Get-ExecutionPolicy -Scope CurrentUser) -in @('Undefined', 'Restricted')) {
    try { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force }
    catch {
        # A process-level Bypass can report an override even after the write succeeds.
        if ((Get-ExecutionPolicy -Scope CurrentUser) -ne 'RemoteSigned') { throw }
    }
}


if (-not $SkipPlugins) {
    $nvim = (Get-Command nvim -ErrorAction Stop).Source
    $lockPath = Join-Path $repoPath 'nvim/lazy-lock.json'
    $lockBytes = [System.IO.File]::ReadAllBytes($lockPath)
    # The first launch can add newly discovered dependencies to the lock file.
    # Keep the checked-in versions, then restore against the original lock.
    try {
        & $nvim --headless '+qa'
        if ($LASTEXITCODE -ne 0) { throw 'Neovim first-run bootstrap failed.' }
        [System.IO.File]::WriteAllBytes($lockPath, $lockBytes)
        & $nvim --headless '+Lazy! restore' '+qa'
        if ($LASTEXITCODE -ne 0) { throw 'Neovim plugin restore failed.' }
        & $nvim --headless -S (Join-Path $PSScriptRoot 'setup-neovim.lua')
        if ($LASTEXITCODE -ne 0) { throw 'Neovim parser/tool setup failed.' }
    } finally {
        [System.IO.File]::WriteAllBytes($lockPath, $lockBytes)
    }
}

if (-not $SkipAutoHotkey -or $RegisterAutoHotkeyStartup) {
    $ahkCandidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs/AutoHotkey/v2/AutoHotkey64.exe'),
        (Join-Path $env:ProgramFiles 'AutoHotkey/v2/AutoHotkey64.exe')
    )
    $ahkExe = $ahkCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $ahkExe) { throw 'AutoHotkey v2 executable not found.' }
    $ahkScript = Join-Path $repoPath 'autoHotKey.ahk'
    if ($RegisterAutoHotkeyStartup) {
        $shortcutPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'dotfiles-AutoHotkey.lnk'
        $shortcutExists = Test-Path -LiteralPath $shortcutPath
        $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcutPath)
        $shortcutMatches = $shortcutExists -and $shortcut.TargetPath -eq $ahkExe -and
            $shortcut.Arguments -eq ('"' + $ahkScript + '"') -and $shortcut.WorkingDirectory -eq $repoPath
        if ($shortcutExists -and -not $shortcutMatches) {
            Copy-Item -LiteralPath $shortcutPath -Destination ($shortcutPath + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
        }
        if (-not $shortcutMatches) {
            $shortcut.TargetPath = $ahkExe
            $shortcut.Arguments = '"' + $ahkScript + '"'
            $shortcut.WorkingDirectory = $repoPath
            $shortcut.WindowStyle = 7
            $shortcut.Save()
        }
    }
    if (-not $SkipAutoHotkey) {
        $ahkLog = Join-Path $env:TEMP ('dotfiles-ahk-' + [guid]::NewGuid().ToString() + '.log')
        $ahkProcess = Start-Process -FilePath $ahkExe -ArgumentList '/ErrorStdOut', ('"' + $ahkScript + '"') -WindowStyle Hidden -RedirectStandardOutput $ahkLog -PassThru
        if ($ahkProcess.WaitForExit(2000)) {
            throw ('AutoHotkey failed: ' + [System.IO.File]::ReadAllText($ahkLog))
        }
    }
}
Write-Output "Windows setup complete. Reopen $Terminal to pick up the refreshed PATH and PowerShell 7."
if ($Terminal -eq 'windows-terminal') { Write-Output 'Choose Windows Terminal as the default terminal application in Windows Settings if desired; this setup does not change that system setting.' }
if ($WithPsmux) { Write-Output 'Open a new PowerShell 7 tab and run mux to use the repository psmux settings.' }
Write-Output 'Copilot authentication and language-specific runtimes are configured separately.'
