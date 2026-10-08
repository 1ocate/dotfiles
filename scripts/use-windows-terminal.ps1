#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Plan, [switch]$Check, [switch]$ApprovePowerShell, [switch]$ArchivePreviousProgress,
    [ValidateSet('stable','preview','unpackaged')][string]$Channel='stable')
$ErrorActionPreference='Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This adapter requires native Windows; WSL/macOS/Linux are not targets.' }
if ($Plan -and $Check) { throw 'Plan and Check cannot be combined.' }
$repoPath = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'windows-environment.ps1')
. (Join-Path $PSScriptRoot 'windows-terminal.ps1')
$source = Join-Path $repoPath 'windows-terminal/settings.json'
if (-not (Test-Path -LiteralPath (Join-Path $repoPath 'windows-terminal/.gitignore') -PathType Leaf)) { throw 'Windows Terminal runtime ignore rules are missing; no settings were changed.' }
$target = Get-WindowsTerminalTarget -Channel $Channel
$connection = Get-WindowsTerminalConnection -SourcePath $source -TargetPath $target
$setupPath = Join-Path $repoPath '.local/setup-state.json'
$setupState = $null
if (Test-Path -LiteralPath $setupPath) {
    $setupState = Get-Content -LiteralPath $setupPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($setupState.components -isnot [pscustomobject]) { throw 'Invalid setup-state components; preserve and repair the local record before linking.' }
}
$otherProgress = $setupState -and ($setupState.host -ne [Environment]::MachineName -or $setupState.environment -ne 'windows-powershell')
if ($Plan -or $Check) {
    Write-WindowsSelectionStatus -RepoPath $repoPath
    Write-Output ('Windows Terminal ' + $Channel + ': ' + $connection.Status)
    Write-Output ('Source: ' + $connection.Source)
    Write-Output ('Target: ' + $connection.Target)
    Write-Output 'Apply requires the local PowerShell approval and a permitted directory junction. Existing settings are backed up; no OS default-terminal setting is changed.'
    if ($otherProgress) { Write-Output 'Progress record belongs to another host/environment. Apply requires explicit -ArchivePreviousProgress; no completed statuses are imported.' }
    if ($Check) { Assert-WindowsTerminalPrograms -Channel $Channel -TargetPath $target }
    return
}
Assert-WindowsPowerShellSelection -RepoPath $repoPath -ApprovePowerShell:$ApprovePowerShell
Assert-WindowsTerminalPrograms -Channel $Channel -TargetPath $target
# Inspect actual other-channel links independently of missing/archived progress.
foreach ($otherChannel in @('stable','preview','unpackaged')) {
    if ($otherChannel -eq $Channel) { continue }
    $otherDirectory = Split-Path -Parent (Get-WindowsTerminalTarget -Channel $otherChannel)
    $otherItem = Get-Item -LiteralPath $otherDirectory -Force -ErrorAction SilentlyContinue
    if ($otherItem -and $otherItem.LinkType -in @('Junction','SymbolicLink')) {
        $otherSource = [string](@($otherItem.Target)[0])
        if (-not [IO.Path]::IsPathRooted($otherSource)) { $otherSource = Join-Path (Split-Path -Parent $otherDirectory) $otherSource }
        if ([IO.Path]::GetFullPath($otherSource).TrimEnd('\') -eq $connection.SourceDirectory.TrimEnd('\')) {
            throw ('Another channel still references this checkout: ' + $otherChannel + '. Restore that directory before connecting another channel.')
        }
    }
}
$progressBackup = $null
if ($otherProgress) {
    if (-not $ArchivePreviousProgress) { throw 'Progress record belongs to another host/environment. Review it and use -ArchivePreviousProgress explicitly to back it up and start a current-host record. Existing settings were not changed.' }
    $progressBackup = $setupPath + '.backup-' + [guid]::NewGuid().ToString('N')
    Copy-Item -LiteralPath $setupPath -Destination $progressBackup
    $setupState = $null
}
if (-not $setupState) {
    $setupState = [pscustomobject]@{scope='local';environment='windows-powershell';host=[Environment]::MachineName;components=[pscustomobject]@{}}
    if ($progressBackup) { $setupState | Add-Member -NotePropertyName previous_progress_backup -NotePropertyValue $progressBackup }
}
$previous = $setupState.components.windows_terminal
$result = Connect-WindowsTerminalSource -SourcePath $source -TargetPath $target
$settingsBackup = $null
if ($result.Backup) { $settingsBackup = $result.Backup }
elseif ($previous -and $previous.source -eq $result.Source -and $previous.target -eq $result.Target) { $settingsBackup = $previous.backup }
$component = [pscustomobject]@{status='linked';host=[Environment]::MachineName;channel=$Channel;source=$result.Source;target=$result.Target;backup=$settingsBackup;
    verification='JSON parsed and directory-junction target checked. GUI/IME and fresh-machine installation are not verified.';checked_at=(Get-Date -Format o)}
if (-not $previous -or $previous.host -ne $component.host -or $previous.source -ne $component.source -or $previous.target -ne $component.target -or $previous.status -ne 'linked' -or $previous.channel -ne $component.channel -or $previous.backup -ne $component.backup) {
    $setupState.components | Add-Member -NotePropertyName windows_terminal -NotePropertyValue $component -Force
    $setupState | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $setupPath -Encoding UTF8
}
Write-Output ('Windows Terminal source connected: ' + $result.Source)
if ($result.Backup) { Write-Output ('Previous settings directory backed up: ' + $result.Backup) }
Write-Output 'Open a new Windows Terminal window. Edit windows-terminal/settings.json in the checkout; runtime state is ignored by Git. Check the diff after Settings UI saves before committing.'
